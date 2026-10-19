pub mod api;
pub mod auth;
pub mod config_view;
pub mod dashboard;
pub mod rules_view;

use crate::auth::{SessionStore, SESSION_COOKIE};
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
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ));

    let public_routes = Router::new()
        .route("/login", get(auth::login_page).post(auth::handle_login))
        .route("/api/login", post(auth::handle_login_api))
        .route("/logout", get(auth::handle_logout))
        .route("/api/captcha", get(auth::get_captcha_api))
        .route("/health", get(|| async { "OK" }));

    Router::new()
        .merge(public_routes)
        .merge(protected_routes)
        .with_state(state)
}

async fn auth_middleware(
    State(state): State<AppState>,
    req: Request<Body>,
    next: Next,
) -> Response {
    let path = req.uri().path().to_string();
    let mut authenticated = false;
    let mut authed_user: Option<String> = None;

    let cookie_header_raw = req.headers()
        .get(header::COOKIE)
        .and_then(|h| h.to_str().ok())
        .unwrap_or("<NENHUM HEADER COOKIE>");

    tracing::info!("auth_middleware: rota '{}' - Header Cookie recebido: '{}'", path, cookie_header_raw);

    if let Some(cookie_hdr) = req.headers().get(header::COOKIE) {
        if let Ok(cookie_str) = cookie_hdr.to_str() {
            for part in cookie_str.split(';') {
                let part = part.trim();
                if let Some(token) = part.strip_prefix(&format!("{}=", SESSION_COOKIE)) {
                    let clean_token = token.trim_matches('"').trim();
                    tracing::info!("auth_middleware: tentando validar token extraído '{}'", clean_token);
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
        tracing::debug!("auth_middleware: acesso permitido a '{}' para {:?}", path, authed_user);
        next.run(req).await
    } else {
        tracing::warn!("auth_middleware: acesso não autenticado na rota '{}'. Redirecionando para /login.", path);
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

impl axum::extract::FromRef<AppState> for (Arc<tokio::sync::RwLock<Config>>, SessionStore) {
    fn from_ref(state: &AppState) -> Self {
        (state.config.clone(), state.session_store.clone())
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

