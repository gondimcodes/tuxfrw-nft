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
        // SEC-03: Não logar token bruto nos logs
        tracing::debug!("create_session: nova sessão registrada para usuário '{}'. Total ativas: {}", username, lock.len());
        token
    }

    /// SEC-08: Validação otimizada via trava de LEITURA compartilhada (fast-path).
    /// SEC-03: Sem vazamento de tokens brutos nos logs do sistema.
    pub async fn validate_session(&self, token: &str) -> Option<String> {
        let now = Utc::now();

        // 1. Fast path: leitura compartilhada sem bloquear outras threads
        {
            let lock = self.sessions.read().await;
            if let Some(session) = lock.get(token) {
                if session.expires_at > now {
                    return Some(session.username.clone());
                }
            } else {
                return None;
            }
        }

        // 2. Slow path: sessão expirada encontrada, adquire trava de escrita para remoção
        let mut lock = self.sessions.write().await;
        if let Some(session) = lock.get(token) {
            if session.expires_at <= now {
                tracing::debug!("validate_session: sessão expirada removida para '{}'", session.username);
                lock.remove(token);
                None
            } else {
                Some(session.username.clone())
            }
        } else {
            None
        }
    }

    pub async fn destroy_session(&self, token: &str) {
        let mut lock = self.sessions.write().await;
        lock.remove(token);
    }
}
