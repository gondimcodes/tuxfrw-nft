use crate::auth::{verify_password, CaptchaEngine, SessionStore, SESSION_COOKIE};
use crate::config::Config;
use askama::Template;
use axum::{
    extract::State,
    http::{
        header::{HeaderMap, SET_COOKIE},
        StatusCode,
    },
    response::{Html, IntoResponse, Redirect, Response},
    Form, Json,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::warn;

#[derive(Template)]
#[template(path = "login.html")]
pub struct LoginTemplate {
    pub error_message: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginForm {
    pub username: String,
    pub password: String,
    #[serde(default)]
    pub captcha_id: String,
    #[serde(default)]
    pub captcha_code: String,
}

#[derive(Serialize)]
pub struct LoginResponse {
    pub success: bool,
    pub redirect: Option<String>,
    pub error: Option<String>,
}

pub async fn login_page() -> Html<String> {
    let tpl = LoginTemplate { error_message: None };
    Html(tpl.render().unwrap_or_default())
}

pub async fn get_captcha_api(
    State((config, _)): State<(Arc<tokio::sync::RwLock<Config>>, SessionStore)>,
) -> Response {
    let cfg = config.read().await;
    match CaptchaEngine::generate(&cfg.auth.secret_key) {
        Ok(res) => Json(res).into_response(),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({
                "success": false,
                "error": format!("Falha ao gerar CAPTCHA: {}", e)
            })),
        )
            .into_response(),
    }
}

pub async fn handle_login_api(
    State((config, session_store)): State<(Arc<tokio::sync::RwLock<Config>>, SessionStore)>,
    Json(form): Json<LoginForm>,
) -> Response {
    let cfg = config.read().await;

    // 1. Validação estrita do CAPTCHA Criptográfico
    let is_captcha_valid = CaptchaEngine::verify(
        &form.captcha_id,
        &form.captcha_code,
        &cfg.auth.secret_key,
        300,
    );

    if !is_captcha_valid {
        warn!("Tentativa de login rejeitada por CAPTCHA inválido ou expirado para usuário: {}", form.username);
        return (
            StatusCode::BAD_REQUEST,
            Json(LoginResponse {
                success: false,
                redirect: None,
                error: Some("Código CAPTCHA incorreto ou expirado. Digite o novo desafio gerado.".to_string()),
            }),
        )
            .into_response();
    }

    // 2. Validação das Credenciais Argon2id
    let valid_user = form.username == cfg.auth.username;
    let valid_pass = verify_password(&form.password, &cfg.auth.password_hash);

    if valid_user && valid_pass {
        tracing::info!("Login JSON efetuado com sucesso para o usuário: {}", form.username);
        let timeout_minutes = if cfg.auth.session_timeout_minutes == 0 {
            60
        } else {
            cfg.auth.session_timeout_minutes
        };

        let token = session_store
            .create_session(&form.username, timeout_minutes as i64)
            .await;

        let secure_attr = if cfg.server.tls_enabled { "; Secure" } else { "" };
        let cookie_header = format!(
            "{}={}; Path=/; HttpOnly{}; SameSite=Lax; Max-Age={}",
            SESSION_COOKIE,
            token,
            secure_attr,
            timeout_minutes * 60
        );

        tracing::info!("Set-Cookie 200 OK gerado no login JSON: {}", cookie_header);

        let mut response = Json(LoginResponse {
            success: true,
            redirect: Some("/".to_string()),
            error: None,
        })
        .into_response();

        response.headers_mut().insert(
            SET_COOKIE,
            cookie_header.parse().unwrap(),
        );
        response
    } else {
        warn!("Falha de autenticação para o usuário: {}", form.username);
        (
            StatusCode::UNAUTHORIZED,
            Json(LoginResponse {
                success: false,
                redirect: None,
                error: Some("Credenciais inválidas. Verifique o usuário e a senha.".to_string()),
            }),
        )
            .into_response()
    }
}

pub async fn handle_login(
    State((config, session_store)): State<(Arc<tokio::sync::RwLock<Config>>, SessionStore)>,
    Form(form): Form<LoginForm>,
) -> Response {
    let cfg = config.read().await;

    // 1. Validação estrita do CAPTCHA Criptográfico (ADR / Anti-Brute-Force)
    let is_captcha_valid = CaptchaEngine::verify(
        &form.captcha_id,
        &form.captcha_code,
        &cfg.auth.secret_key,
        300, // Validade de 5 minutos (300 segundos)
    );

    if !is_captcha_valid {
        warn!("Tentativa de login rejeitada por CAPTCHA inválido ou expirado para usuário: {}", form.username);
        let tpl = LoginTemplate {
            error_message: Some("Código CAPTCHA incorreto ou expirado. Digite o novo desafio gerado.".to_string()),
        };
        return Html(tpl.render().unwrap_or_default()).into_response();
    }

    // 2. Validação das Credenciais Argon2id
    let valid_user = form.username == cfg.auth.username;
    let valid_pass = verify_password(&form.password, &cfg.auth.password_hash);

    if valid_user && valid_pass {
        tracing::info!("Login efetuado com sucesso para o usuário: {}", form.username);
        let timeout_minutes = if cfg.auth.session_timeout_minutes == 0 {
            60
        } else {
            cfg.auth.session_timeout_minutes
        };

        let token = session_store
            .create_session(&form.username, timeout_minutes as i64)
            .await;

        let cookie_header = format!(
            "{}={}; Path=/; HttpOnly; Max-Age={}",
            SESSION_COOKIE,
            token,
            timeout_minutes * 60
        );

        tracing::info!("Set-Cookie gerado no login: {}", cookie_header);

        let mut response = Redirect::to("/").into_response();
        response.headers_mut().insert(
            SET_COOKIE,
            cookie_header.parse().unwrap(),
        );
        response
    } else {
        warn!("Failed login attempt for user: {}", form.username);
        let tpl = LoginTemplate {
            error_message: Some("Credenciais inválidas. Verifique o usuário e a senha.".to_string()),
        };
        Html(tpl.render().unwrap_or_default()).into_response()
    }
}

pub async fn handle_logout(
    headers: HeaderMap,
    State((_config, session_store)): State<(Arc<tokio::sync::RwLock<Config>>, SessionStore)>,
) -> Response {
    if let Some(cookie_hdr) = headers.get(axum::http::header::COOKIE) {
        if let Ok(cookie_str) = cookie_hdr.to_str() {
            for part in cookie_str.split(';') {
                let part = part.trim();
                if let Some(token) = part.strip_prefix(&format!("{}=", SESSION_COOKIE)) {
                    let clean_token = token.trim_matches('"').trim();
                    session_store.destroy_session(clean_token).await;
                }
            }
        }
    }

    let mut resp = Redirect::to("/login").into_response();
    resp.headers_mut().insert(
        SET_COOKIE,
        format!("{}=; Path=/; Max-Age=0; HttpOnly", SESSION_COOKIE)
            .parse()
            .unwrap(),
    );
    resp
}

