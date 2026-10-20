use crate::firewall::{ConfigService, FirewallManager};
use askama::Template;
use axum::{
    extract::State,
    response::{Html, Json},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Template)]
#[template(path = "config.html")]
pub struct ConfigTemplate {
    pub raw_content: String,
    pub conf_path: String,
    pub tuxfrw_version: String,
    pub web_version: &'static str,
}

#[derive(Deserialize)]
pub struct UpdateConfigRequest {
    pub content: String,
}

#[derive(Serialize)]
pub struct UpdateConfigResponse {
    pub success: bool,
    pub path: String,
    pub error: Option<String>,
}

pub async fn config_page(
    State(firewall): State<Arc<FirewallManager>>,
    State(config_service): State<Arc<ConfigService>>,
) -> Html<String> {
    let tuxfrw_version = firewall.get_tuxfrw_version().await;
    let conf_view = config_service.read_tuxfrw_conf().unwrap_or_else(|_| {
        crate::firewall::TuxfrwConfigView {
            raw_content: "# Não foi possível ler o arquivo tuxfrw.conf".to_string(),
            parsed_variables: Default::default(),
        }
    });

    let tpl = ConfigTemplate {
        raw_content: conf_view.raw_content,
        conf_path: config_service.get_conf_path().to_string_lossy().to_string(),
        tuxfrw_version,
        web_version: env!("CARGO_PKG_VERSION"),
    };

    Html(tpl.render().unwrap_or_default())
}

pub async fn update_config_api(
    State(config_service): State<Arc<ConfigService>>,
    Json(payload): Json<UpdateConfigRequest>,
) -> Json<UpdateConfigResponse> {
    match config_service.save_tuxfrw_conf(&payload.content) {
        Ok(_) => Json(UpdateConfigResponse {
            success: true,
            path: config_service.get_conf_path().to_string_lossy().to_string(),
            error: None,
        }),
        Err(e) => Json(UpdateConfigResponse {
            success: false,
            path: config_service.get_conf_path().to_string_lossy().to_string(),
            error: Some(e.to_string()),
        }),
    }
}

