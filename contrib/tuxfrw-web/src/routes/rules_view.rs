use crate::firewall::ConfigService;
use askama::Template;
use axum::{
    extract::{Path, Query, State},
    response::{Html, Json},
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct RuleModuleItem {
    pub file_name: String,
    pub is_selected: bool,
}

#[derive(Template)]
#[template(path = "rules.html")]
pub struct RulesTemplate {
    pub modules: Vec<RuleModuleItem>,
    pub current_file: String,
    pub module_short_name: String,
    pub content: String,
    pub description: String,
}

#[derive(Deserialize)]
pub struct RulesQuery {
    pub file: Option<String>,
}

#[derive(Deserialize)]
pub struct UpdateRuleRequest {
    pub content: String,
}

#[derive(Serialize)]
pub struct UpdateRuleResponse {
    pub success: bool,
    pub error: Option<String>,
}

pub async fn rules_page(
    State(config_service): State<Arc<ConfigService>>,
    Query(query): Query<RulesQuery>,
) -> Html<String> {
    let module_files = config_service.list_rule_modules().unwrap_or_default();
    let selected_file = query
        .file
        .or_else(|| module_files.first().cloned())
        .unwrap_or_else(|| "tf_INPUT.mod".to_string());

    let rule_file = config_service
        .read_rule_module(&selected_file)
        .unwrap_or_else(|_| crate::firewall::RuleModuleFile {
            name: selected_file.replace("tf_", "").replace(".mod", ""),
            file_name: selected_file.clone(),
            content: "# Não foi possível ler o módulo selecionado".to_string(),
            description: String::new(),
        });

    let modules: Vec<RuleModuleItem> = module_files
        .into_iter()
        .map(|f| {
            let is_selected = f == selected_file;
            RuleModuleItem {
                file_name: f,
                is_selected,
            }
        })
        .collect();

    let tpl = RulesTemplate {
        modules,
        current_file: rule_file.file_name,
        module_short_name: rule_file.name,
        content: rule_file.content,
        description: rule_file.description,
    };

    Html(tpl.render().unwrap_or_default())
}

pub async fn update_rule_api(
    State(config_service): State<Arc<ConfigService>>,
    Path(file): Path<String>,
    Json(payload): Json<UpdateRuleRequest>,
) -> Json<UpdateRuleResponse> {
    match config_service.save_rule_module(&file, &payload.content) {
        Ok(_) => Json(UpdateRuleResponse {
            success: true,
            error: None,
        }),
        Err(e) => Json(UpdateRuleResponse {
            success: false,
            error: Some(e.to_string()),
        }),
    }
}
