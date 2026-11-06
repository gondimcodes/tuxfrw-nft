use std::fs;
use std::process::Command;

#[test]
fn test_regression_docker_mode_preserves_nat_tables() {
    // Regression test for issue: clear_rules unconditionally deleted table ip nat and table ip6 nat,
    // destroying Docker container NAT and port forwardings.
    let base_mod_path = std::path::Path::new("../../tf_BASE.mod");
    assert!(
        base_mod_path.exists(),
        "tf_BASE.mod must exist in root repository"
    );

    let temp_conf_dir = std::env::temp_dir().join(format!("tf_test_{}", uuid::Uuid::new_v4()));
    fs::create_dir_all(&temp_conf_dir).expect("Failed to create temp conf dir");
    let temp_conf_str = temp_conf_dir.to_str().unwrap();

    // 1. Test DOCKER_SUPPORT="1"
    let script_docker_1 = format!(
        r#"
        export CONF_DIR="{}"
        export NFT_BIN="/usr/sbin/nft"
        export DOCKER_SUPPORT="1"
        source ../../tf_BASE.mod
        clear_rules
    "#,
        temp_conf_str
    );

    let output_docker_1 = Command::new("bash")
        .arg("-c")
        .arg(&script_docker_1)
        .output()
        .expect("Failed to execute bash test script for DOCKER_SUPPORT=1");

    assert!(
        output_docker_1.status.success(),
        "clear_rules script execution failed: {}",
        String::from_utf8_lossy(&output_docker_1.stderr)
    );

    let generated_nft_docker = fs::read_to_string(format!("{}/tuxfrw.nft", temp_conf_str))
        .expect("Failed to read generated tuxfrw.nft");

    // When DOCKER_SUPPORT="1", TuxFrw MUST clean its own tables:
    assert!(
        generated_nft_docker.contains("delete table inet filter"),
        "Should clean table inet filter"
    );
    assert!(
        generated_nft_docker.contains("delete table netdev filter"),
        "Should clean table netdev filter"
    );
    assert!(
        generated_nft_docker.contains("delete table inet mangle"),
        "Should clean table inet mangle"
    );

    // CRITICAL: Must NEVER contain delete table ip nat or delete table ip6 nat!
    assert!(
        !generated_nft_docker.contains("delete table ip nat"),
        "CRITICAL REGRESSION: clear_rules in Docker mode must NOT delete table ip nat!"
    );
    assert!(
        !generated_nft_docker.contains("delete table ip6 nat"),
        "CRITICAL REGRESSION: clear_rules in Docker mode must NOT delete table ip6 nat!"
    );
    assert!(
        !generated_nft_docker.contains("add table ip nat"),
        "clear_rules in Docker mode must NOT touch table ip nat!"
    );
    assert!(
        !generated_nft_docker.contains("add table ip6 nat"),
        "clear_rules in Docker mode must NOT touch table ip6 nat!"
    );

    // 2. Test DOCKER_SUPPORT="0" (Classic Gateway Mode)
    let script_gateway = format!(
        r#"
        export CONF_DIR="{}"
        export NFT_BIN="/usr/sbin/nft"
        export DOCKER_SUPPORT="0"
        source ../../tf_BASE.mod
        clear_rules
    "#,
        temp_conf_str
    );

    let output_gateway = Command::new("bash")
        .arg("-c")
        .arg(&script_gateway)
        .output()
        .expect("Failed to execute bash test script for DOCKER_SUPPORT=0");

    assert!(output_gateway.status.success());

    let generated_nft_gateway = fs::read_to_string(format!("{}/tuxfrw.nft", temp_conf_str))
        .expect("Failed to read generated tuxfrw.nft");

    // In Gateway mode, TuxFrw manages NAT and cleans its own nat tables:
    assert!(
        generated_nft_gateway.contains("delete table ip nat"),
        "Gateway mode must purge table ip nat"
    );
    assert!(
        generated_nft_gateway.contains("delete table ip6 nat"),
        "Gateway mode must purge table ip6 nat"
    );

    // Cleanup
    let _ = fs::remove_dir_all(&temp_conf_dir);
}

#[test]
fn test_regression_version_6_0_4_consistency() {
    let version_content = fs::read_to_string("../../VERSION").expect("Failed to read VERSION file");
    assert_eq!(version_content.trim(), "6.0.4");

    let tuxfrw_script =
        fs::read_to_string("../../tuxfrw-nft").expect("Failed to read tuxfrw-nft script");
    assert!(
        tuxfrw_script.contains("TUXFRW_VERSION=\"6.0.4\""),
        "tuxfrw-nft script must have version 6.0.4"
    );
}
