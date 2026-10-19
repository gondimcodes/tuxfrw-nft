use chrono::{DateTime, Duration, Utc};
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use uuid::Uuid;

pub const SESSION_COOKIE: &str = "tuxfrw_session";

#[derive(Debug, Clone)]
pub struct Session {
    pub username: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Clone, Default)]
pub struct SessionStore {
    sessions: Arc<RwLock<HashMap<String, Session>>>,
}

impl SessionStore {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn create_session(&self, username: &str, timeout_minutes: i64) -> String {
        let token = Uuid::new_v4().to_string();
        let expires_at = Utc::now() + Duration::minutes(timeout_minutes);

        let session = Session {
            username: username.to_string(),
            expires_at,
        };

        let mut lock = self.sessions.write().await;
        // Purge expired sessions while inserting
        let now = Utc::now();
        lock.retain(|_, s| s.expires_at > now);

        lock.insert(token.clone(), session);
        tracing::info!("create_session: token '{}' registrado para '{}'. Total ativas: {}", token, username, lock.len());
        token
    }

    pub async fn validate_session(&self, token: &str) -> Option<String> {
        let mut lock = self.sessions.write().await;
        let now = Utc::now();
        tracing::info!("validate_session: buscando token '{}'. Total no store: {}", token, lock.len());

        if let Some(session) = lock.get(token) {
            tracing::info!("validate_session: encontrado para '{}', expira em: {:?}, now: {:?}", session.username, session.expires_at, now);
            if session.expires_at > now {
                return Some(session.username.clone());
            } else {
                tracing::warn!("validate_session: sessão expirada para token '{}'!", token);
            }
        } else {
            tracing::warn!("validate_session: token '{}' NÃO existe no store!", token);
        }

        // Clean up expired or invalid
        lock.remove(token);
        None
    }

    pub async fn destroy_session(&self, token: &str) {
        let mut lock = self.sessions.write().await;
        lock.remove(token);
    }
}
