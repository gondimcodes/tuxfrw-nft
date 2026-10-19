use axum_server::tls_rustls::RustlsConfig;
use std::path::Path;
use tracing::{info, warn};

pub async fn load_or_generate_tls(
    cert_path: &str,
    key_path: &str,
    auto_generate: bool,
) -> Result<RustlsConfig, Box<dyn std::error::Error + Send + Sync>> {
    let cert_p = Path::new(cert_path);
    let key_p = Path::new(key_path);

    if cert_p.exists() && key_p.exists() {
        info!("Loading TLS certificate from {:?} and key from {:?}", cert_p, key_p);
        return Ok(RustlsConfig::from_pem_file(cert_p, key_p).await?);
    }

    if !auto_generate {
        return Err(format!(
            "TLS certificates not found at {:?} / {:?}, and auto_generate_self_signed is false",
            cert_p, key_p
        )
        .into());
    }

    warn!(
        "TLS certificates not found at {:?} / {:?}. Generating self-signed ECDSA certificate...",
        cert_p, key_p
    );

    let cert = rcgen::generate_simple_self_signed(vec![
        "localhost".to_string(),
        "127.0.0.1".to_string(),
        "::1".to_string(),
    ])?;

    let cert_pem = cert.cert.pem();
    let key_pem = cert.key_pair.serialize_pem();

    if let Some(parent) = cert_p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    if let Some(parent) = key_p.parent() {
        std::fs::create_dir_all(parent)?;
    }

    std::fs::write(cert_p, &cert_pem)?;
    std::fs::write(key_p, &key_pem)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(key_p)?.permissions();
        perms.set_mode(0o600);
        std::fs::set_permissions(key_p, perms)?;
    }

    info!("Self-signed TLS certificate successfully saved to {:?}", cert_p);
    Ok(RustlsConfig::from_pem(cert_pem.into_bytes(), key_pem.into_bytes()).await?)
}

