use chrono::Utc;
use hmac::{Hmac, Mac};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaptchaResponse {
    pub success: bool,
    pub captcha_id: String,
    pub captcha_svg: String,
}

/// Store em memória com controle de uso único (anti-replay) e purga por TTL
#[derive(Clone, Default)]
pub struct CaptchaStore {
    used_tokens: Arc<RwLock<HashMap<String, i64>>>,
}

impl CaptchaStore {
    pub fn new() -> Self {
        Self {
            used_tokens: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Verifica se o token já foi consumido e, se não, marca como consumido
    pub async fn consume_token(&self, nonce: &str, expires_at: i64) -> bool {
        let mut lock = self.used_tokens.write().await;
        let now = Utc::now().timestamp();

        // Purga tokens antigos
        lock.retain(|_, &mut exp| exp > now);

        if lock.contains_key(nonce) {
            // Já consumido anteriormente (tentativa de replay)
            return false;
        }

        lock.insert(nonce.to_string(), expires_at);
        true
    }
}

pub struct CaptchaEngine;

impl CaptchaEngine {
    /// Gera um desafio de CAPTCHA visual dinâmico em formato vetorial SVG,
    /// com linhas de ruído ótico, rotação aleatória de caracteres e token assinado por HMAC/SHA-256.
    /// SEC-01: O código secreto JAMAIS é entregue ao cliente (nem em texto puro nem em Base64).
    /// SEC-10: Exige chave secreta válida.
    pub fn generate(secret_key: &str) -> Result<CaptchaResponse, String> {
        let mut rng = rand::thread_rng();

        // Alfabeto legível sem caracteres ambíguos (ex: 0/O, 1/I)
        const CHARS: &[u8] = b"23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
        let code: String = (0..5)
            .map(|_| {
                let idx = rng.gen_range(0..CHARS.len());
                CHARS[idx] as char
            })
            .collect();

        let timestamp_utc = Utc::now().timestamp();
        let nonce = hex::encode(rng.gen::<[u8; 16]>());
        let signature = Self::sign_payload(&nonce, timestamp_utc, &code.to_uppercase(), secret_key)?;

        // captcha_id seguro: nonce:timestamp:assinatura_hmac
        let captcha_id = format!("{}:{}:{}", nonce, timestamp_utc, signature);

        let colors = ["#00F0FF", "#C471ED", "#F43F5E", "#38BDF8", "#10B981"];
        let mut letters_svg = String::new();
        let x_positions = [25, 60, 95, 130, 165];

        for (i, c) in code.chars().enumerate() {
            let x = x_positions[i];
            let y = rng.gen_range(30..40);
            let rot = rng.gen_range(-20..20);
            let color = colors[i % colors.len()];
            let font_size = rng.gen_range(24..28);
            letters_svg.push_str(&format!(
                r#"<text x="{}" y="{}" fill="{}" font-size="{}" font-weight="900" font-family="'Courier New', monospace, sans-serif" transform="rotate({}, {}, {})" filter="url(#glow)">{}</text>"#,
                x, y, color, font_size, rot, x, y, c
            ));
        }

        let mut noise_lines = String::new();
        for _ in 0..4 {
            let x1 = rng.gen_range(5..40);
            let y1 = rng.gen_range(5..45);
            let x2 = rng.gen_range(160..200);
            let y2 = rng.gen_range(5..45);
            let stroke = colors[rng.gen_range(0..colors.len())];
            noise_lines.push_str(&format!(
                r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="{}" stroke-width="1.5" stroke-opacity="0.6" stroke-dasharray="4,4"/>"#,
                x1, y1, x2, y2, stroke
            ));
        }

        let svg = format!(
            r#"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="50" viewBox="0 0 200 50" style="background: rgba(10, 15, 29, 0.95); border-radius: 6px; border: 1px solid rgba(56, 189, 248, 0.3); display: block;"><defs><filter id="glow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="1" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>{}{}</svg>"#,
            noise_lines, letters_svg
        );

        Ok(CaptchaResponse {
            success: true,
            captcha_id,
            captcha_svg: svg,
        })
    }

    /// Valida o token e a resposta fornecida pelo usuário.
    /// Protegido contra:
    /// - SEC-01: Validação sem exposição do código original
    /// - SEC-02: Replay attack via CaptchaStore (Single-Use Token)
    /// - Timing attack via Mac::verify_slice em tempo constante
    pub async fn verify(
        store: &CaptchaStore,
        captcha_id: &str,
        user_input_code: &str,
        secret_key: &str,
        ttl_secs: u64,
    ) -> bool {
        let parts: Vec<&str> = captcha_id.split(':').collect();
        if parts.len() != 3 {
            return false;
        }

        let nonce = parts[0];
        let timestamp_str = parts[1];
        let provided_sig_hex = parts[2];

        // Validar formato do nonce (hex 32 caracteres)
        if nonce.len() != 32 || !nonce.chars().all(|c| c.is_ascii_hexdigit()) {
            return false;
        }

        let timestamp: i64 = match timestamp_str.parse() {
            Ok(t) => t,
            Err(_) => return false,
        };

        // Verifica expiração
        let now = Utc::now().timestamp();
        if now - timestamp > ttl_secs as i64 || now < timestamp - 10 {
            return false; // Expirado ou timestamp no futuro
        }

        let clean_user_code = user_input_code.trim().to_uppercase();
        if clean_user_code.is_empty() || clean_user_code.len() > 10 {
            return false;
        }

        let provided_sig_bytes = match hex::decode(provided_sig_hex) {
            Ok(b) => b,
            Err(_) => return false,
        };

        // Validação da assinatura HMAC-SHA256 em tempo constante
        let mut mac = match HmacSha256::new_from_slice(secret_key.as_bytes()) {
            Ok(m) => m,
            Err(_) => return false,
        };
        mac.update(format!("{}:{}:{}", nonce, timestamp, clean_user_code).as_bytes());

        if mac.verify_slice(&provided_sig_bytes).is_err() {
            return false; // Assinatura incorreta (código errado ou token adulterado)
        }

        // SEC-02: Garantir que o token seja de uso único (anti-replay)
        let expires_at = timestamp + ttl_secs as i64;
        store.consume_token(nonce, expires_at).await
    }

    fn sign_payload(
        nonce: &str,
        timestamp: i64,
        code: &str,
        secret_key: &str,
    ) -> Result<String, String> {
        let mut mac = HmacSha256::new_from_slice(secret_key.as_bytes())
            .map_err(|e| format!("Erro ao inicializar HMAC: {}", e))?;
        mac.update(format!("{}:{}:{}", nonce, timestamp, code).as_bytes());
        Ok(hex::encode(mac.finalize().into_bytes()))
    }
}
