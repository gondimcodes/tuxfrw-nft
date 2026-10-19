use chrono::Utc;
use hmac::{Hmac, Mac};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaptchaResponse {
    pub success: bool,
    pub captcha_id: String,
    pub captcha_svg: String,
}

pub struct CaptchaEngine;

impl CaptchaEngine {
    /// Gera um desafio de CAPTCHA visual dinâmico em formato vetorial SVG,
    /// com linhas de ruído ótico, rotação aleatória de caracteres e token assinado por HMAC/SHA-256.
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
        let signature = Self::sign_payload(&code.to_uppercase(), timestamp_utc, secret_key)?;

        let encoded_code = base64::Engine::encode(
            &base64::engine::general_purpose::STANDARD,
            code.to_uppercase(),
        );

        let captcha_id = format!("{}:{}:{}", encoded_code, timestamp_utc, signature);

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

    /// Valida o token e a resposta fornecida pelo usuário
    pub fn verify(
        captcha_id: &str,
        user_input_code: &str,
        secret_key: &str,
        ttl_secs: u64,
    ) -> bool {
        let parts: Vec<&str> = captcha_id.split(':').collect();
        if parts.len() != 3 {
            return false;
        }

        let encoded_code = parts[0];
        let timestamp_str = parts[1];
        let provided_sig = parts[2];

        let timestamp: i64 = match timestamp_str.parse() {
            Ok(t) => t,
            Err(_) => return false,
        };

        // Verifica expiração
        let now = Utc::now().timestamp();
        if now - timestamp > ttl_secs as i64 || now < timestamp - 10 {
            return false; // Expirado ou timestamp no futuro
        }

        let decoded_bytes = match base64::Engine::decode(
            &base64::engine::general_purpose::STANDARD,
            encoded_code,
        ) {
            Ok(b) => b,
            Err(_) => return false,
        };

        let real_code = match String::from_utf8(decoded_bytes) {
            Ok(s) => s,
            Err(_) => return false,
        };

        // Validação da assinatura criptográfica
        let expected_sig = match Self::sign_payload(&real_code, timestamp, secret_key) {
            Ok(s) => s,
            Err(_) => return false,
        };

        if expected_sig != provided_sig {
            return false; // Token adulterado
        }

        // Comparação insensível a maiúsculas/minúsculas e espaços
        let clean_user_code = user_input_code.trim().to_uppercase();
        clean_user_code == real_code
    }

    fn sign_payload(code: &str, timestamp: i64, secret_key: &str) -> Result<String, String> {
        let effective_key = if secret_key.is_empty() {
            "tuxfrw-default-secure-captcha-seed-hmac"
        } else {
            secret_key
        };

        let mut mac = HmacSha256::new_from_slice(effective_key.as_bytes())
            .map_err(|e| format!("Erro ao inicializar HMAC: {}", e))?;
        mac.update(format!("{}:{}", code, timestamp).as_bytes());
        Ok(hex::encode(mac.finalize().into_bytes()))
    }
}

