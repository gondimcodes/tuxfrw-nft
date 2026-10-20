use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use tracing::info;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TuxfrwConfigView {
    pub raw_content: String,
    pub parsed_variables: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleModuleFile {
    pub name: String,
    pub file_name: String,
    pub content: String,
    pub description: String,
}

pub struct ConfigService {
    config_dir: PathBuf,
    nft_bin: PathBuf,
}

impl ConfigService {
    pub fn new(config_dir: &str, nft_bin: &str) -> Self {
        Self {
            config_dir: PathBuf::from(config_dir),
            nft_bin: PathBuf::from(nft_bin),
        }
    }

    pub fn get_conf_path(&self) -> PathBuf {
        self.config_dir.join("tuxfrw.conf")
    }

    pub fn get_rules_dir(&self) -> PathBuf {
        self.config_dir.join("rules")
    }

    pub fn read_tuxfrw_conf(&self) -> io::Result<TuxfrwConfigView> {
        let conf_path = self.get_conf_path();
        let raw = if conf_path.exists() {
            fs::read_to_string(&conf_path)?
        } else {
            String::new()
        };

        let mut parsed = BTreeMap::new();
        for line in raw.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = trimmed.split_once('=') {
                let key = k.trim().to_string();
                let val = v.trim().trim_matches('"').trim_matches('\'').to_string();
                parsed.insert(key, val);
            }
        }

        Ok(TuxfrwConfigView {
            raw_content: raw,
            parsed_variables: parsed,
        })
    }

    pub fn validate_bash_syntax(&self, content: &str, display_name: &str) -> Result<(), String> {
        let temp_dir = std::env::temp_dir();
        let temp_file_path = temp_dir.join(format!(".tuxfrw_syntax_chk_{}.tmp", uuid::Uuid::new_v4()));

        fs::write(&temp_file_path, content)
            .map_err(|e| format!("Falha ao criar arquivo temporário de validação: {}", e))?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&temp_file_path, fs::Permissions::from_mode(0o600));
        }

        struct TempCleanup(PathBuf);
        impl Drop for TempCleanup {
            fn drop(&mut self) {
                let _ = fs::remove_file(&self.0);
            }
        }
        let _cleanup = TempCleanup(temp_file_path.clone());

        let bash_output = std::process::Command::new("bash")
            .arg("-n")
            .arg(&temp_file_path)
            .output()
            .map_err(|e| format!("Erro ao executar validador bash: {}", e))?;

        if !bash_output.status.success() {
            let stderr = String::from_utf8_lossy(&bash_output.stderr);
            let sanitized = stderr.replace(&temp_file_path.to_string_lossy().to_string(), display_name);
            return Err(format!("Erro de sintaxe Bash:\n{}", sanitized.trim()));
        }

        Ok(())
    }

    pub fn save_tuxfrw_conf(&self, content: &str) -> io::Result<()> {
        // SEC-09: Validação sintática obrigatória antes de gravar tuxfrw.conf
        if let Err(val_err) = self.validate_bash_syntax(content, "tuxfrw.conf") {
            return Err(io::Error::new(io::ErrorKind::InvalidData, val_err));
        }

        let conf_path = self.get_conf_path();
        self.write_atomic(&conf_path, content)?;
        info!("Saved updated tuxfrw.conf to {:?}", conf_path);
        Ok(())
    }

    pub fn list_rule_modules(&self) -> io::Result<Vec<String>> {
        let rules_dir = self.get_rules_dir();
        let mut modules = Vec::new();

        if rules_dir.exists() {
            for entry in fs::read_dir(rules_dir)? {
                let entry = entry?;
                let file_name = entry.file_name().to_string_lossy().to_string();
                if file_name.starts_with("tf_") && file_name.ends_with(".mod") {
                    modules.push(file_name);
                }
            }
        }
        modules.sort();
        Ok(modules)
    }

    pub fn read_rule_module(&self, file_name: &str) -> io::Result<RuleModuleFile> {
        // Sanitize to prevent path traversal
        let safe_name = Path::new(file_name)
            .file_name()
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "Nome de arquivo inválido"))?
            .to_string_lossy();

        // SEC-07: Restrição estrita ao formato de módulo de regras do TuxFrw
        if !safe_name.starts_with("tf_") || !safe_name.ends_with(".mod") {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Nome de módulo inválido. Deve iniciar com tf_ e terminar com .mod",
            ));
        }

        let path = self.get_rules_dir().join(safe_name.as_ref());
        let content = fs::read_to_string(&path)?;

        let desc = content
            .lines()
            .find(|line| line.starts_with("# tf_") || line.contains("rules module") || line.contains("directional"))
            .unwrap_or("")
            .trim_start_matches('#')
            .trim()
            .to_string();

        Ok(RuleModuleFile {
            name: safe_name.replace("tf_", "").replace(".mod", ""),
            file_name: safe_name.to_string(),
            content,
            description: desc,
        })
    }

    pub fn validate_rule_module(&self, file_name: &str, content: &str) -> Result<(), String> {
        let safe_name = Path::new(file_name)
            .file_name()
            .ok_or_else(|| "Nome de arquivo inválido".to_string())?
            .to_string_lossy();

        if !safe_name.starts_with("tf_") || !safe_name.ends_with(".mod") {
            return Err("Nome de módulo inválido. Deve iniciar com tf_ e terminar com .mod".to_string());
        }

        // 1. Gravar em arquivo temporário isolado
        let temp_dir = std::env::temp_dir();
        let temp_file_path = temp_dir.join(format!(".tuxfrw_val_{}.mod", uuid::Uuid::new_v4()));

        fs::write(&temp_file_path, content)
            .map_err(|e| format!("Falha ao criar arquivo temporário de validação: {}", e))?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&temp_file_path, fs::Permissions::from_mode(0o600));
        }

        // Limpeza garantida do arquivo temporário
        struct TempCleanup(PathBuf);
        impl Drop for TempCleanup {
            fn drop(&mut self) {
                let _ = fs::remove_file(&self.0);
            }
        }
        let _cleanup = TempCleanup(temp_file_path.clone());

        // 2. Validação Nível 1: Sintaxe Bash com bash -n
        let bash_output = std::process::Command::new("bash")
            .arg("-n")
            .arg(&temp_file_path)
            .output()
            .map_err(|e| format!("Erro ao executar validador bash: {}", e))?;

        if !bash_output.status.success() {
            let stderr = String::from_utf8_lossy(&bash_output.stderr);
            let sanitized = stderr.replace(&temp_file_path.to_string_lossy().to_string(), &safe_name);
            return Err(format!("Erro de sintaxe Bash:\n{}", sanitized.trim()));
        }

        // 3. Validação Nível 2: Simulação de carregamento e validação nftables com nft -c
        let nft_bin_str = self.nft_bin.to_string_lossy().to_string();
        let config_dir_str = self.config_dir.to_string_lossy().to_string();
        let temp_file_str = temp_file_path.to_string_lossy().to_string();

        let script = r#"
            set -e
            CONF_DIR="$1"
            TEMP_MOD="$2"
            NFT_BIN="$3"

            if [ ! -x "$NFT_BIN" ]; then
                exit 0
            fi

            TMP_NFT=$(mktemp /tmp/.tuxfrw_nft_chk_XXXXXX.nft)
            trap 'rm -f "$TMP_NFT"' EXIT

            cat << 'EOF' > "$TMP_NFT"
table inet filter {
    chain INPUT { }
    chain FORWARD { }
    chain OUTPUT { }
    chain DMZ-EXT { }
    chain DMZ-INT { }
    chain DMZ-VPN { }
    chain EXT-DMZ { }
    chain EXT-INT { }
    chain EXT-VPN { }
    chain INT-DMZ { }
    chain INT-EXT { }
    chain INT-VPN { }
    chain VPN-DMZ { }
    chain VPN-EXT { }
    chain VPN-INT { }
    chain synproxy-prerouting { type filter hook prerouting priority raw; }
}
table ip nat {
    chain PREROUTING { }
    chain POSTROUTING { }
}
table ip6 nat {
    chain PREROUTING { }
    chain POSTROUTING { }
}
table inet mangle {
    chain PREROUTING { }
    chain POSTROUTING { }
}
table netdev filter {
}
EOF

            [ -f "$CONF_DIR/tuxfrw.conf" ] && . "$CONF_DIR/tuxfrw.conf"
            [ -f "$CONF_DIR/cloudflare.conf" ] && . "$CONF_DIR/cloudflare.conf"
            [ -f "$CONF_DIR/tf_BASE.mod" ] && . "$CONF_DIR/tf_BASE.mod"

            NFT="echo"

            if command -v defines >/dev/null 2>&1; then
                defines >> "$TMP_NFT" 2>/dev/null || true
            else
                echo 'define bogons_v4 = { 0.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 192.0.0.0/24, 192.0.2.0/24, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }' >> "$TMP_NFT"
                echo 'define bogons_v6 = { 0100::/64, 2001:2::/48, 2001:10::/28, 2001:db8::/32, 3ffe::/16, fc00::/7, fec0::/10, ff00::/8 }' >> "$TMP_NFT"
            fi

            . "$TEMP_MOD" >> "$TMP_NFT"

            "$NFT_BIN" -c -f "$TMP_NFT"
        "#;

        let nft_check_output = std::process::Command::new("bash")
            .arg("-c")
            .arg(script)
            .arg("_")
            .arg(&config_dir_str)
            .arg(&temp_file_str)
            .arg(&nft_bin_str)
            .output()
            .map_err(|e| format!("Erro ao executar verificação do nftables: {}", e))?;

        if !nft_check_output.status.success() {
            let stderr = String::from_utf8_lossy(&nft_check_output.stderr);
            let sanitized = stderr
                .replace(&temp_file_str, &safe_name)
                .lines()
                .filter(|line| !line.contains(".tuxfrw_nft_chk_"))
                .collect::<Vec<&str>>()
                .join("\n");

            let err_msg = if sanitized.trim().is_empty() {
                stderr.trim().to_string()
            } else {
                sanitized.trim().to_string()
            };

            return Err(format!("Erro de sintaxe nftables:\n{}", err_msg));
        }

        Ok(())
    }

    pub fn save_rule_module(&self, file_name: &str, content: &str) -> io::Result<()> {
        let safe_name = Path::new(file_name)
            .file_name()
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "Nome de arquivo inválido"))?;

        // Validação obrigatória pré-salvamento: bloqueia a gravação se houver erros de sintaxe
        if let Err(val_err) = self.validate_rule_module(file_name, content) {
            return Err(io::Error::new(io::ErrorKind::InvalidData, val_err));
        }

        let path = self.get_rules_dir().join(safe_name);
        self.write_atomic(&path, content)?;
        info!("Saved rule module to {:?}", path);
        Ok(())
    }

    fn write_atomic(&self, target: &Path, content: &str) -> io::Result<()> {
        let parent = target.parent().unwrap_or_else(|| Path::new("."));
        fs::create_dir_all(parent)?;
        let tmp = parent.join(format!(".tmp.{}", uuid::Uuid::new_v4()));
        fs::write(&tmp, content)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = fs::Permissions::from_mode(0o600);
            let _ = fs::set_permissions(&tmp, perms);
        }

        fs::rename(&tmp, target)?;
        Ok(())
    }
}

