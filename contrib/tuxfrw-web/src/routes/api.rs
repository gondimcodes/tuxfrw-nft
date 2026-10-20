use crate::firewall::{CommandResult, FirewallAction, FirewallManager};
use axum::{
    extract::{Path, State},
    response::Json,
};
use serde::Serialize;
use std::sync::Arc;

#[derive(Serialize)]
pub struct StatusApiResponse {
    pub output: String,
}

#[derive(Serialize)]
pub struct VersionApiResponse {
    pub tuxfrw_version: String,
    pub web_version: String,
}

pub async fn get_version_api(
    State(firewall): State<Arc<FirewallManager>>,
) -> Json<VersionApiResponse> {
    let tuxfrw_version = firewall.get_tuxfrw_version().await;
    Json(VersionApiResponse {
        tuxfrw_version,
        web_version: env!("CARGO_PKG_VERSION").to_string(),
    })
}

pub async fn run_action_api(
    State(firewall): State<Arc<FirewallManager>>,
    Path(action): Path<String>,
) -> Json<CommandResult> {
    let action_enum = match action.to_lowercase().as_str() {
        "start" => FirewallAction::Start,
        "stop" => FirewallAction::Stop,
        "restart" => FirewallAction::Restart,
        "panic" => FirewallAction::Panic,
        "cf-update" => FirewallAction::CfUpdate,
        _ => {
            return Json(CommandResult {
                success: false,
                exit_code: Some(1),
                stdout: String::new(),
                stderr: format!("Ação desconhecida solicitada: {}", action),
            });
        }
    };

    match firewall.execute(action_enum).await {
        Ok(res) => Json(res),
        Err(e) => Json(CommandResult {
            success: false,
            exit_code: Some(1),
            stdout: String::new(),
            stderr: format!("Erro ao executar comando: {}", e),
        }),
    }
}

pub async fn load_module_api(
    State(firewall): State<Arc<FirewallManager>>,
    Path(module): Path<String>,
) -> Json<CommandResult> {
    match firewall.execute(FirewallAction::LoadModule(module)).await {
        Ok(res) => Json(res),
        Err(e) => Json(CommandResult {
            success: false,
            exit_code: Some(1),
            stdout: String::new(),
            stderr: format!("Erro ao recarregar módulo: {}", e),
        }),
    }
}

pub async fn get_status_api(
    State(firewall): State<Arc<FirewallManager>>,
) -> Json<StatusApiResponse> {
    let output = match firewall.execute(FirewallAction::Status).await {
        Ok(res) => {
            if !res.stdout.is_empty() {
                res.stdout
            } else {
                res.stderr
            }
        }
        Err(e) => format!("Erro ao obter status: {}", e),
    };

    Json(StatusApiResponse { output })
}

