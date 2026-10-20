pub mod api;
pub mod auth;
pub mod config_view;
pub mod dashboard;
pub mod rules_view;

use crate::auth::{CaptchaStore, SessionStore, SESSION_COOKIE};
use crate::config::Config;
use crate::firewall::{ConfigService, FirewallManager};
use axum::{
    body::Body,
    extract::State,
    http::{header, Request, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Redirect, Response},
    routing::{get, post},
    Router,
};
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub config: Arc<tokio::sync::RwLock<Config>>,
    pub session_store: SessionStore,
    pub captcha_store: CaptchaStore,
    pub firewall: Arc<FirewallManager>,
    pub config_service: Arc<ConfigService>,
}

pub fn create_router(state: AppState) -> Router {
    let protected_routes = Router::new()
        .route("/", get(dashboard::dashboard_page))
        .route("/dashboard", get(dashboard::dashboard_page))
        .route("/config", get(config_view::config_page))
        .route("/rules", get(rules_view::rules_page))
        .route("/api/config", post(config_view::update_config_api))
        .route("/api/rules/:file", post(rules_view::update_rule_api))
        .route("/api/action/:action", post(api::run_action_api))
        .route("/api/load/:module", post(api::load_module_api))
        .route("/api/status", get(api::get_status_api))
        .route("/api/version", get(api::get_version_api))
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ));

    let public_routes = Router::new()
        .route("/login", get(auth::login_page).post(auth::handle_login))
        .route("/api/login", post(auth::handle_login_api))
        .route("/logout", get(auth::handle_logout))
        .route("/api/captcha", get(auth::get_captcha_api))
        .route("/health", get(|| async { "OK" }))
        .route("/static/hero_bg.png", get(hero_bg_handler));

    Router::new()
        .merge(public_routes)
        .merge(protected_routes)
        .layer(middleware::from_fn_with_state(
            state.clone(),
            security_headers_middleware,
        ))
        .with_state(state)
}

/// SEC-04: Middleware de injeção de Headers HTTP Defensivos
async fn security_headers_middleware(
    State(state): State<AppState>,
    req: Request<Body>,
    next: Next,
) -> Response {
    let is_tls = {
        let cfg = state.config.read().await;
        cfg.server.tls_enabled
    };

    let mut response = next.run(req).await;
    let headers = response.headers_mut();

    headers.insert(header::X_FRAME_OPTIONS, "DENY".parse().unwrap());
    headers.insert(header::X_CONTENT_TYPE_OPTIONS, "nosniff".parse().unwrap());
    headers.insert(header::REFERRER_POLICY, "strict-origin-when-cross-origin".parse().unwrap());
    headers.insert(
        header::CONTENT_SECURITY_POLICY,
        "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:;".parse().unwrap(),
    );

    if is_tls {
        headers.insert(
            header::STRICT_TRANSPORT_SECURITY,
            "max-age=31536000; includeSubDomains".parse().unwrap(),
        );
    }

    response
}

/// Middleware de autenticação de sessão via Cookie
/// SEC-03: Sem vazamento de identificadores de sessão nem dados de cookie em logs
async fn auth_middleware(
    State(state): State<AppState>,
    req: Request<Body>,
    next: Next,
) -> Response {
    let path = req.uri().path().to_string();
    let mut authenticated = false;
    let mut authed_user: Option<String> = None;

    if let Some(cookie_hdr) = req.headers().get(header::COOKIE) {
        if let Ok(cookie_str) = cookie_hdr.to_str() {
            for part in cookie_str.split(';') {
                let part = part.trim();
                if let Some(token) = part.strip_prefix(&format!("{}=", SESSION_COOKIE)) {
                    let clean_token = token.trim_matches('"').trim();
                    if let Some(user) = state.session_store.validate_session(clean_token).await {
                        authenticated = true;
                        authed_user = Some(user);
                        break;
                    }
                }
            }
        }
    }

    if authenticated {
        tracing::trace!("auth_middleware: acesso autenticado a '{}' para {:?}", path, authed_user);
        next.run(req).await
    } else {
        tracing::debug!("auth_middleware: acesso não autenticado na rota '{}'. Redirecionando para /login.", path);
        if path.starts_with("/api/") {
            (
                StatusCode::UNAUTHORIZED,
                [("Content-Type", "application/json")],
                r#"{"error":"Não autorizado. Efetue login para continuar."}"#,
            )
                .into_response()
        } else {
            Redirect::to("/login").into_response()
        }
    }
}

impl axum::extract::FromRef<AppState> for Arc<FirewallManager> {
    fn from_ref(state: &AppState) -> Self {
        state.firewall.clone()
    }
}

impl axum::extract::FromRef<AppState> for Arc<ConfigService> {
    fn from_ref(state: &AppState) -> Self {
        state.config_service.clone()
    }
}

async fn hero_bg_handler() -> Response {
    const HERO_BG: &[u8] = include_bytes!("../../static/hero_bg.png");
    (
        [
            (header::CONTENT_TYPE, "image/png"),
            (header::CACHE_CONTROL, "public, max-age=31536000, immutable"),
        ],
        HERO_BG,
    )
        .into_response()
}
