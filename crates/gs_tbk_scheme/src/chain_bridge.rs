use anyhow::{bail, Context, Result};
use log::{info, warn};
use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[derive(Clone, Copy, Debug)]
pub enum ChainApp {
    PersonalInfo,
    Signature,
}

#[derive(Clone, Debug)]
pub struct ChainCommandOutput {
    pub stdout: String,
    pub stderr: String,
}

impl ChainCommandOutput {
    pub fn labeled_value<'a>(&'a self, label: &str) -> Option<&'a str> {
        self.stdout.lines().find_map(|line| {
            let trimmed = line.trim_start();
            let rest = trimmed.strip_prefix(label)?;
            if rest.is_empty() {
                return Some("");
            }

            if rest
                .chars()
                .next()
                .map(|ch| ch.is_whitespace())
                .unwrap_or(false)
            {
                Some(rest.trim_start())
            } else {
                None
            }
        })
    }
}

impl ChainApp {
    fn app_dir_env(self) -> &'static str {
        match self {
            ChainApp::PersonalInfo => "GSTBK_PERSONAL_INFO_APP_DIR",
            ChainApp::Signature => "GSTBK_SIGNATURE_APP_DIR",
        }
    }

    fn address_env(self) -> &'static str {
        match self {
            ChainApp::PersonalInfo => "GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS",
            ChainApp::Signature => "GSTBK_SIGNATURE_CONTRACT_ADDRESS",
        }
    }

    fn default_app_dir(self) -> &'static str {
        match self {
            ChainApp::PersonalInfo | ChainApp::Signature => "chain-apps/fisco-bcos-java-sdk",
        }
    }

    fn script_name(self) -> &'static str {
        match self {
            ChainApp::PersonalInfo => "info_run.sh",
            ChainApp::Signature => "signature_run.sh",
        }
    }

    fn value_label(self) -> &'static str {
        match self {
            ChainApp::PersonalInfo => "info",
            ChainApp::Signature => "signature",
        }
    }
}

pub fn register_personal_info(
    user: &str,
    payload_path: impl AsRef<Path>,
) -> Result<ChainCommandOutput> {
    register(ChainApp::PersonalInfo, user, payload_path)
}

pub fn query_personal_info(user: &str) -> Result<ChainCommandOutput> {
    query(ChainApp::PersonalInfo, user)
}

pub fn register_signature(
    user: &str,
    payload_path: impl AsRef<Path>,
) -> Result<ChainCommandOutput> {
    register(ChainApp::Signature, user, payload_path)
}

pub fn query_signature(user: &str) -> Result<ChainCommandOutput> {
    query(ChainApp::Signature, user)
}

pub fn log_command_output(label: &str, output: &ChainCommandOutput) {
    let stdout = output.stdout.trim();
    if !stdout.is_empty() {
        info!("{} stdout:\n{}", label, stdout);
        println!("{} stdout:\n{}", label, stdout);
    }

    let stderr = output.stderr.trim();
    if !stderr.is_empty() {
        warn!("{} stderr:\n{}", label, stderr);
        println!("{} stderr:\n{}", label, stderr);
    }
}

fn register(
    app: ChainApp,
    user: &str,
    payload_path: impl AsRef<Path>,
) -> Result<ChainCommandOutput> {
    let payload_path = payload_path.as_ref();
    if !payload_path.is_file() {
        bail!(
            "{} payload file does not exist: {}",
            app.value_label(),
            payload_path.display()
        );
    }

    let payload_arg = payload_path.to_str().with_context(|| {
        format!(
            "payload path is not valid UTF-8: {}",
            payload_path.display()
        )
    })?;

    run_script(app, &["register", user, payload_arg])
}

fn query(app: ChainApp, user: &str) -> Result<ChainCommandOutput> {
    run_script(app, &["select", user])
}

fn run_script(app: ChainApp, args: &[&str]) -> Result<ChainCommandOutput> {
    require_contract_address(app)?;
    let script_path = find_script(app)?;
    let script_dir = script_path
        .parent()
        .with_context(|| format!("script has no parent directory: {}", script_path.display()))?;

    let output = Command::new("bash")
        .arg(&script_path)
        .args(args)
        .current_dir(script_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .with_context(|| {
            format!(
                "failed to execute {} with args {:?}",
                script_path.display(),
                args
            )
        })?;

    let command_output = ChainCommandOutput {
        stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    };

    if !output.status.success() {
        bail!(
            "{} failed with status {}\nstdout:\n{}\nstderr:\n{}\nCheck FISCO_CONFIG, FISCO_GROUP, contract address env vars, and SDK conf/certs when this is a Java SDK wrapper.",
            script_path.display(),
            output.status,
            command_output.stdout.trim(),
            command_output.stderr.trim()
        );
    }

    Ok(command_output)
}

fn require_contract_address(app: ChainApp) -> Result<()> {
    let env_name = app.address_env();
    let address = env::var(env_name).unwrap_or_default();
    let address = address.trim();
    if address.is_empty() || address == "0x0000000000000000000000000000000000000000" {
        bail!(
            "missing contract address: set {} to the deployed {} contract address",
            env_name,
            app.value_label()
        );
    }
    Ok(())
}

fn find_script(app: ChainApp) -> Result<PathBuf> {
    let app_dir = configured_app_dir(app)?;
    let candidates = [
        app_dir.join(app.script_name()),
        app_dir.join("dist").join(app.script_name()),
    ];

    for candidate in candidates {
        if candidate.is_file() {
            return Ok(candidate);
        }
    }

    bail!(
        "{} not found under {}. Set {} to a directory containing {} or dist/{}",
        app.script_name(),
        app_dir.display(),
        app.app_dir_env(),
        app.script_name(),
        app.script_name()
    );
}

fn configured_app_dir(app: ChainApp) -> Result<PathBuf> {
    let raw = env::var_os(app.app_dir_env())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(app.default_app_dir()));
    Ok(resolve_path(raw)?)
}

fn resolve_path(path: PathBuf) -> Result<PathBuf> {
    if path.is_absolute() {
        return Ok(path);
    }

    let root = match env::var_os("GSTBK_REPO_ROOT") {
        Some(value) => PathBuf::from(value),
        None => env::current_dir().context("failed to read current directory")?,
    };

    Ok(if root.is_absolute() {
        root.join(path)
    } else {
        env::current_dir()
            .context("failed to read current directory")?
            .join(root)
            .join(path)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::Mutex;
    use std::time::{SystemTime, UNIX_EPOCH};

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    #[cfg(unix)]
    fn register_and_select_use_wrapper_scripts() {
        let _lock = ENV_LOCK.lock().unwrap();
        let temp_dir = unique_temp_dir();
        fs::create_dir_all(&temp_dir).unwrap();
        write_fake_script(
            &temp_dir.join("signature_run.sh"),
            "signature",
            "{\"signature\":true}",
        );
        write_fake_script(&temp_dir.join("info_run.sh"), "info", "{\"info\":true}");
        let signature_payload = temp_dir.join("signature.json");
        let info_payload = temp_dir.join("info.json");
        fs::write(&signature_payload, "{\"payload\":\"signature\"}").unwrap();
        fs::write(&info_payload, "{\"payload\":\"info\"}").unwrap();

        let _guard = EnvGuard::set(vec![
            ("GSTBK_SIGNATURE_APP_DIR", temp_dir.to_str().unwrap()),
            ("GSTBK_PERSONAL_INFO_APP_DIR", temp_dir.to_str().unwrap()),
            (
                "GSTBK_SIGNATURE_CONTRACT_ADDRESS",
                "0x1111111111111111111111111111111111111111",
            ),
            (
                "GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS",
                "0x2222222222222222222222222222222222222222",
            ),
        ]);

        let signature_register = register_signature("user1", &signature_payload).unwrap();
        assert!(signature_register.stdout.contains("transactionHash 0xtest"));
        assert_eq!(
            query_signature("user1")
                .unwrap()
                .labeled_value("signature")
                .unwrap(),
            "{\"signature\":true}"
        );

        let info_register = register_personal_info("user1", &info_payload).unwrap();
        assert!(info_register.stdout.contains("transactionHash 0xtest"));
        assert_eq!(
            query_personal_info("user1")
                .unwrap()
                .labeled_value("info")
                .unwrap(),
            "{\"info\":true}"
        );

        fs::remove_dir_all(temp_dir).unwrap();
    }

    #[test]
    #[cfg(unix)]
    fn missing_contract_address_reports_env_name() {
        let _lock = ENV_LOCK.lock().unwrap();
        let temp_dir = unique_temp_dir();
        fs::create_dir_all(&temp_dir).unwrap();
        write_fake_script(
            &temp_dir.join("signature_run.sh"),
            "signature",
            "{\"signature\":true}",
        );

        let _guard = EnvGuard::apply(vec![
            ("GSTBK_SIGNATURE_APP_DIR", Some(temp_dir.to_str().unwrap())),
            ("GSTBK_SIGNATURE_CONTRACT_ADDRESS", None),
        ]);

        let err = query_signature("user1").unwrap_err().to_string();
        assert!(err.contains("GSTBK_SIGNATURE_CONTRACT_ADDRESS"));
        assert!(err.contains("deployed signature contract address"));

        fs::remove_dir_all(temp_dir).unwrap();
    }

    #[test]
    #[cfg(unix)]
    fn missing_script_reports_app_dir_env_name() {
        let _lock = ENV_LOCK.lock().unwrap();
        let temp_dir = unique_temp_dir();
        fs::create_dir_all(&temp_dir).unwrap();

        let _guard = EnvGuard::apply(vec![
            ("GSTBK_SIGNATURE_APP_DIR", Some(temp_dir.to_str().unwrap())),
            (
                "GSTBK_SIGNATURE_CONTRACT_ADDRESS",
                Some("0x1111111111111111111111111111111111111111"),
            ),
        ]);

        let err = query_signature("user1").unwrap_err().to_string();
        assert!(err.contains("signature_run.sh not found"));
        assert!(err.contains("GSTBK_SIGNATURE_APP_DIR"));
        assert!(err.contains(temp_dir.to_str().unwrap()));

        fs::remove_dir_all(temp_dir).unwrap();
    }

    #[cfg(unix)]
    fn write_fake_script(path: &Path, label: &str, selected_value: &str) {
        fs::write(
            path,
            format!(
                r#"#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  register)
    echo "ret 0"
    echo "status 0x0"
    echo "transactionHash 0xtest"
    echo "{label} $(cat "$3")"
    ;;
  select)
    printf '%s\n' 'exists true'
    printf '%s %s\n' '{label}' '{selected_value}'
    ;;
  *)
    echo "unexpected command: $1" >&2
    exit 2
    ;;
esac
"#
            ),
        )
        .unwrap();
    }

    #[cfg(unix)]
    fn unique_temp_dir() -> PathBuf {
        let millis = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis();
        env::temp_dir().join(format!(
            "gstbk-chain-bridge-{}-{}",
            std::process::id(),
            millis
        ))
    }

    struct EnvGuard {
        old_values: Vec<(&'static str, Option<String>)>,
    }

    impl EnvGuard {
        fn set(values: Vec<(&'static str, &str)>) -> EnvGuard {
            EnvGuard::apply(
                values
                    .into_iter()
                    .map(|(key, value)| (key, Some(value)))
                    .collect(),
            )
        }

        fn apply(values: Vec<(&'static str, Option<&str>)>) -> EnvGuard {
            let old_values = values
                .iter()
                .map(|(key, _)| (*key, env::var(key).ok()))
                .collect::<Vec<_>>();
            for (key, value) in values {
                if let Some(value) = value {
                    env::set_var(key, value);
                } else {
                    env::remove_var(key);
                }
            }
            EnvGuard { old_values }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            for (key, value) in &self.old_values {
                if let Some(value) = value {
                    env::set_var(key, value);
                } else {
                    env::remove_var(key);
                }
            }
        }
    }
}
