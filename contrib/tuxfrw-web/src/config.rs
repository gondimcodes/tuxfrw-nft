use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub server: ServerConfig,
    #[serde(default)]
    pub auth: AuthConfig,
    #[serde(default)]
    pub firewall: FirewallConfig,
    #[serde(skip)]
    pub active_path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub listen: String,
    pub base_path: String,
    pub tls_enabled: bool,
    pub cert_path: String,
    pub key_path: String,
    pub auto_generate_self_signed: bool,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            listen: "[::]:8443".to_string(),
            base_path: "/".to_string(),
            tls_enabled: true,
            cert_path: "/etc/tuxfrw-nft/tls/cert.pem".to_string(),
            key_path: "/etc/tuxfrw-nft/tls/key.pem".to_string(),
            auto_generate_self_signed: true,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthConfig {
    pub username: String,
    pub password_hash: String,
    pub session_timeout_minutes: u64,
    pub secret_key: String,
}

impl Default for AuthConfig {
    fn default() -> Self {
        Self {
            username: "admin".to_string(),
            // Default hash for "admin"
            password_hash: "$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$59f1rFvjDsmE8Fj2kU+sV3R6/pL2y3rB8Q2wVb1zKxY".to_string(),
            session_timeout_minutes: 60,
            secret_key: String::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FirewallConfig {
    pub tuxfrw_bin: String,
    pub config_dir: String,
    pub nft_bin: String,
    pub command_timeout_seconds: u64,
}

impl Default for FirewallConfig {
    fn default() -> Self {
        Self {
            tuxfrw_bin: "/usr/sbin/tuxfrw-nft".to_string(),
            config_dir: "/etc/tuxfrw-nft".to_string(),
            nft_bin: "/usr/sbin/nft".to_string(),
            command_timeout_seconds: 15,
        }
    }
}

impl Config {
    pub fn load() -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let candidate_paths = vec![
            std::env::var("TUXFRW_CONFIG").ok().map(PathBuf::from),
            Some(PathBuf::from("/etc/tuxfrw-nft/config.toml")),
            Some(PathBuf::from("config.toml")),
            Some(PathBuf::from("config.example.toml")),
        ];

        for candidate in candidate_paths.into_iter().flatten() {
            if candidate.exists() {
                info!("Loading configuration from {:?}", candidate);
                let content = std::fs::read_to_string(&candidate)?;
                let mut cfg: Config = toml::from_str(&content)?;
                cfg.active_path = candidate;
                return Ok(cfg);
            }
        }

        warn!("No config.toml found. Using default internal configuration.");
        let mut default_cfg = Config::default();
        default_cfg.active_path = PathBuf::from("/etc/tuxfrw-nft/config.toml");
        Ok(default_cfg)
    }

    pub fn save_password_hash(&mut self, new_hash: &str) -> std::io::Result<()> {
        self.auth.password_hash = new_hash.to_string();
        let serialized = toml::to_string_pretty(self)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

        let target_dir = self.active_path.parent().unwrap_or_else(|| Path::new("."));
        let temp_file = target_dir.join(format!(".config.tmp.{}", uuid::Uuid::new_v4()));
        
        std::fs::write(&temp_file, serialized)?;
        std::fs::rename(&temp_file, &self.active_path)?;
        info!("Updated password hash saved to {:?}", self.active_path);
        Ok(())
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: ServerConfig::default(),
            auth: AuthConfig::default(),
            firewall: FirewallConfig::default(),
            active_path: PathBuf::from("/etc/tuxfrw-nft/config.toml"),
        }
    }
}
