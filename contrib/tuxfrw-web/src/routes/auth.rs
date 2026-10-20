use crate::auth::{verify_password, CaptchaEngine, SESSION_COOKIE};
use crate::routes::AppState;
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

/// SEC-06: Helper padronizado para montagem do cookie de sessão
pub fn build_session_cookie(token: &str, max_age_secs: u64, is_tls: bool) -> String {
    let secure_attr = if is_tls { "; Secure" } else { "" };
    format!(
        "{}={}; Path=/; HttpOnly{}; SameSite=Lax; Max-Age={}",
        SESSION_COOKIE, token, secure_attr, max_age_secs
    )
}

/// SEC-06: Helper padronizado para deleção do cookie no logout
pub fn build_logout_cookie(is_tls: bool) -> String {
    let secure_attr = if is_tls { "; Secure" } else { "" };
    format!(
        "{}=; Path=/; Max-Age=0; HttpOnly{}; SameSite=Lax",
        SESSION_COOKIE, secure_attr
    )
}

pub async fn login_page() -> Html<String> {
    let tpl = LoginTemplate { error_message: None };
    Html(tpl.render().unwrap_or_default())
}

pub async fn get_captcha_api(
    State(state): State<AppState>,
) -> Response {
    let cfg = state.config.read().await;
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
    State(state): State<AppState>,
    Json(form): Json<LoginForm>,
) -> Response {
    let cfg = state.config.read().await;

    // 1. Validação estrita do CAPTCHA Criptográfico (SEC-01 & SEC-02)
    let is_captcha_valid = CaptchaEngine::verify(
        &state.captcha_store,
        &form.captcha_id,
        &form.captcha_code,
        &cfg.auth.secret_key,
        300,
    )
    .await;

    if !is_captcha_valid {
        warn!("Tentativa de login rejeitada por CAPTCHA inválido, expirado ou já utilizado para usuário: {}", form.username);
        return (
            StatusCode::BAD_REQUEST,
            Json(LoginResponse {
                success: false,
                redirect: None,
                error: Some("Código CAPTCHA incorreto, expirado ou já utilizado. Digite o novo desafio gerado.".to_string()),
            }),
        )
            .into_response();
    }

    // 2. Validação das Credenciais Argon2id
    let valid_user = form.username == cfg.auth.username;
    let valid_pass = verify_password(&form.password, &cfg.auth.password_hash);

    if valid_user && valid_pass {
        // SEC-03: Não logar tokens nem dados de autenticação em texto puro
        tracing::info!("Login JSON efetuado com sucesso para o usuário: {}", form.username);
        let timeout_minutes = if cfg.auth.session_timeout_minutes == 0 {
            60
        } else {
            cfg.auth.session_timeout_minutes
        };

        let token = state.session_store
            .create_session(&form.username, timeout_minutes as i64)
            .await;

        let cookie_header = build_session_cookie(&token, timeout_minutes * 60, cfg.server.tls_enabled);

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
    State(state): State<AppState>,
    Form(form): Form<LoginForm>,
) -> Response {
    let cfg = state.config.read().await;

    // 1. Validação estrita do CAPTCHA Criptográfico (SEC-01 & SEC-02)
    let is_captcha_valid = CaptchaEngine::verify(
        &state.captcha_store,
        &form.captcha_id,
        &form.captcha_code,
        &cfg.auth.secret_key,
        300,
    )
    .await;

    if !is_captcha_valid {
        warn!("Tentativa de login rejeitada por CAPTCHA inválido, expirado ou já utilizado para usuário: {}", form.username);
        let tpl = LoginTemplate {
            error_message: Some("Código CAPTCHA incorreto, expirado ou já utilizado. Digite o novo desafio gerado.".to_string()),
        };
        return Html(tpl.render().unwrap_or_default()).into_response();
    }

    // 2. Validação das Credenciais Argon2id
    let valid_user = form.username == cfg.auth.username;
    let valid_pass = verify_password(&form.password, &cfg.auth.password_hash);

    if valid_user && valid_pass {
        // SEC-03: Sem vazamento de tokens em log
        tracing::info!("Login efetuado com sucesso para o usuário: {}", form.username);
        let timeout_minutes = if cfg.auth.session_timeout_minutes == 0 {
            60
        } else {
            cfg.auth.session_timeout_minutes
        };

        let token = state.session_store
            .create_session(&form.username, timeout_minutes as i64)
            .await;

        // SEC-06: Garante SameSite=Lax e Secure idênticos ao fluxo JSON
        let cookie_header = build_session_cookie(&token, timeout_minutes * 60, cfg.server.tls_enabled);

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
    State(state): State<AppState>,
) -> Response {
    if let Some(cookie_hdr) = headers.get(axum::http::header::COOKIE) {
        if let Ok(cookie_str) = cookie_hdr.to_str() {
            for part in cookie_str.split(';') {
                let part = part.trim();
                if let Some(token) = part.strip_prefix(&format!("{}=", SESSION_COOKIE)) {
                    let clean_token = token.trim_matches('"').trim();
                    state.session_store.destroy_session(clean_token).await;
                }
            }
        }
    }

    let is_tls = {
        let cfg = state.config.read().await;
        cfg.server.tls_enabled
    };

    let mut resp = Redirect::to("/login").into_response();
    resp.headers_mut().insert(
        SET_COOKIE,
        build_logout_cookie(is_tls)
            .parse()
            .unwrap(),
    );
    resp
}
