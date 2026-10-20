mod auth;
mod config;
mod firewall;
mod routes;
mod tls;

use auth::SessionStore;
use config::Config;
use firewall::{ConfigService, FirewallManager};
use routes::{create_router, AppState};
use std::net::SocketAddr;
use std::sync::Arc;
use tracing::{info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // Explicitly install Ring CryptoProvider for Rustls 0.23
    let _ = rustls::crypto::ring::default_provider().install_default();

    // Initialize structured logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "tuxfrw_web=info,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("Starting TuxFrw-NFT Web Management Daemon v1.0.0 (Dual-Stack IPv6/IPv4 & HTTPS)");

    // CLI helper: generate Argon2id password hash for /etc/tuxfrw-nft/config.toml
    let args: Vec<String> = std::env::args().collect();
    if args.len() >= 3 && args[1] == "--hash-password" {
        match auth::hash_password(&args[2]) {
            Ok(hash) => {
                println!("\nHash Argon2id gerado com sucesso:");
                println!("password_hash = \"{}\"\n", hash);
                return Ok(());
            }
            Err(e) => {
                eprintln!("Erro ao gerar hash: {}", e);
                std::process::exit(1);
            }
        }
    }

    // Load configuration
    let config = Config::load()?;
    let listen_str = config.server.listen.clone();
    let tls_enabled = config.server.tls_enabled;
    let cert_path = config.server.cert_path.clone();
    let key_path = config.server.key_path.clone();
    let auto_gen_tls = config.server.auto_generate_self_signed;

    let firewall_mgr = Arc::new(FirewallManager::new(
        &config.firewall.tuxfrw_bin,
        &config.firewall.nft_bin,
        config.firewall.command_timeout_seconds,
    ));

    let config_service = Arc::new(ConfigService::new(
        &config.firewall.config_dir,
        &config.firewall.nft_bin,
    ));
    let session_store = SessionStore::new();
    let captcha_store = auth::CaptchaStore::new();

    let state = AppState {
        config: Arc::new(tokio::sync::RwLock::new(config)),
        session_store,
        captcha_store,
        firewall: firewall_mgr,
        config_service,
    };

    let app = create_router(state);

    // Parse listening socket address supporting Dual-Stack (e.g. "[::]:8443")
    let addr: SocketAddr = listen_str
        .parse()
        .unwrap_or_else(|_| "[::]:8443".parse().unwrap());

    if tls_enabled {
        info!("HTTPS enabled. Loading TLS configuration for address: {}", addr);
        let rustls_config = tls::load_or_generate_tls(&cert_path, &key_path, auto_gen_tls).await?;
        
        info!("TuxFrw Web Daemon listening on https://{}", addr);
        info!("Dual-Stack: accepts IPv6 and IPv4 connections simultaneously");
        
        axum_server::bind_rustls(addr, rustls_config)
            .serve(app.into_make_service())
            .await?;
    } else {
        warn!("TLS is disabled in configuration. Listening unencrypted on http://{}", addr);
        axum_server::bind(addr)
            .serve(app.into_make_service())
            .await?;
    }

    Ok(())
}

