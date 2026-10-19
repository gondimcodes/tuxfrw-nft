use serde::{Deserialize, Serialize};
use std::process::Stdio;
use std::time::Duration;
use thiserror::Error;
use tokio::process::Command;
use tokio::time::timeout;
use tracing::{error, info};

#[derive(Error, Debug)]
pub enum FirewallError {
    #[error("Command execution timed out after {0:?}")]
    Timeout(Duration),
    #[error("I/O error during execution: {0}")]
    Io(#[from] std::io::Error),
    #[error("Invalid module name requested: {0}")]
    InvalidModule(String),
    #[error("Firewall command failed with code {exit_code:?}: {stderr}")]
    ExecutionFailed {
        exit_code: Option<i32>,
        stderr: String,
        stdout: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandResult {
    pub success: bool,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FirewallAction {
    Start,
    Stop,
    Restart,
    Status,
    Panic,
    CfUpdate,
    LoadModule(String),
}

pub const ALLOWED_MODULES: &[&str] = &[
    "INPUT", "OUTPUT", "FORWARD", "DOCKER", "SYNPROXY", "URPF", "NETDEV",
    "MANGLE", "NAT-IN", "NAT-OUT", "INT-EXT", "EXT-INT", "INT-DMZ", "DMZ-INT",
    "EXT-DMZ", "DMZ-EXT", "INT-VPN", "VPN-INT", "EXT-VPN", "VPN-EXT", "DMZ-VPN", "VPN-DMZ"
];

#[derive(Clone)]
pub struct FirewallManager {
    tuxfrw_bin: String,
    nft_bin: String,
    timeout_duration: Duration,
}

impl FirewallManager {
    pub fn new(tuxfrw_bin: &str, nft_bin: &str, timeout_secs: u64) -> Self {
        Self {
            tuxfrw_bin: tuxfrw_bin.to_string(),
            nft_bin: nft_bin.to_string(),
            timeout_duration: Duration::from_secs(timeout_secs),
        }
    }

    pub async fn execute(&self, action: FirewallAction) -> Result<CommandResult, FirewallError> {
        let mut cmd = Command::new(&self.tuxfrw_bin);
        cmd.stdout(Stdio::piped()).stderr(Stdio::piped());

        match action {
            FirewallAction::Start => {
                info!("Executing tuxfrw-nft start");
                cmd.arg("start");
            }
            FirewallAction::Stop => {
                info!("Executing tuxfrw-nft stop");
                cmd.arg("stop");
            }
            FirewallAction::Restart => {
                info!("Executing tuxfrw-nft restart");
                cmd.arg("restart");
            }
            FirewallAction::Status => {
                cmd.arg("status");
            }
            FirewallAction::Panic => {
                info!("Executing tuxfrw-nft panic (lockdown)");
                cmd.arg("panic");
            }
            FirewallAction::CfUpdate => {
                info!("Executing tuxfrw-nft cf-update");
                cmd.arg("cf-update");
            }
            FirewallAction::LoadModule(module) => {
                let upper = module.to_uppercase();
                if !ALLOWED_MODULES.iter().any(|&m| m == upper) {
                    error!("Attempt to load disallowed module name: {}", module);
                    return Err(FirewallError::InvalidModule(module));
                }
                info!("Executing tuxfrw-nft load {}", upper);
                cmd.args(["load", &upper]);
            }
        }

        let child = cmd.spawn()?;
        let output = match timeout(self.timeout_duration, child.wait_with_output()).await {
            Ok(res) => res?,
            Err(_) => return Err(FirewallError::Timeout(self.timeout_duration)),
        };

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        let success = output.status.success();

        Ok(CommandResult {
            success,
            exit_code: output.status.code(),
            stdout,
            stderr,
        })
    }

    pub async fn get_nft_json(&self) -> Result<serde_json::Value, FirewallError> {
        let mut cmd = Command::new(&self.nft_bin);
        cmd.args(["-j", "list", "ruleset"])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let child = cmd.spawn()?;
        let output = match timeout(self.timeout_duration, child.wait_with_output()).await {
            Ok(res) => res?,
            Err(_) => return Err(FirewallError::Timeout(self.timeout_duration)),
        };

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            return Err(FirewallError::ExecutionFailed {
                exit_code: output.status.code(),
                stderr,
                stdout: String::new(),
            });
        }

        let json: serde_json::Value = serde_json::from_slice(&output.stdout)
            .unwrap_or_else(|_| serde_json::json!({ "nftables": [] }));
        Ok(json)
    }
}

