use crate::firewall::{FirewallAction, FirewallManager, ALLOWED_MODULES};
use askama::Template;
use axum::{
    extract::State,
    http::StatusCode,
    response::{Html, IntoResponse, Response},
};
use std::sync::Arc;

#[derive(Template)]
#[template(path = "dashboard.html")]
pub struct DashboardTemplate {
    pub modules: Vec<String>,
    pub initial_status: String,
}

pub async fn dashboard_page(
    State(firewall): State<Arc<FirewallManager>>,
) -> Response {
    tracing::info!("dashboard_page: renderizando tela principal...");
    let status_res = firewall.execute(FirewallAction::Status).await;
    let initial_status = match status_res {
        Ok(res) => {
            if !res.stdout.is_empty() {
                res.stdout
            } else if !res.stderr.is_empty() {
                res.stderr
            } else {
                "Firewall consultado com sucesso (sem saída).".to_string()
            }
        }
        Err(e) => format!("Erro ao obter status do firewall: {}", e),
    };

    let modules: Vec<String> = ALLOWED_MODULES.iter().map(|&s| s.to_string()).collect();

    let tpl = DashboardTemplate {
        modules,
        initial_status,
    };

    match tpl.render() {
        Ok(html) => Html(html).into_response(),
        Err(e) => {
            tracing::error!("Erro ao renderizar dashboard.html: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Html(format!("<h1>Erro ao renderizar Dashboard</h1><pre>{}</pre>", e)),
            )
                .into_response()
        }
    }
}

