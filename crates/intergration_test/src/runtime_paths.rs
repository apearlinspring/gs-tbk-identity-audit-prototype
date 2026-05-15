use std::env;
use std::path::{Path, PathBuf};

fn env_path(name: &str) -> Option<PathBuf> {
    env::var_os(name)
        .filter(|value| !value.as_os_str().is_empty())
        .map(PathBuf::from)
}

fn current_dir_join(path: impl AsRef<Path>) -> PathBuf {
    env::current_dir().unwrap().join(path)
}

fn runtime_config_path(path: impl AsRef<Path>) -> Option<PathBuf> {
    env_path("GSTBK_RUNTIME_CONFIG_DIR").map(|root| root.join(path))
}

fn runtime_state_path(path: impl AsRef<Path>) -> Option<PathBuf> {
    env_path("GSTBK_RUNTIME_STATE_DIR").map(|root| root.join(path))
}

pub fn proxy_config_path() -> String {
    env_path("GSTBK_PROXY_CONFIG_PATH")
        .or_else(|| runtime_config_path("proxy/proxy_config.json"))
        .unwrap_or_else(|| current_dir_join("src/proxy/config/config_file/proxy_config.json"))
        .to_string_lossy()
        .into_owned()
}

pub fn node_config_path(node_id: u16) -> String {
    env_path("GSTBK_NODE_CONFIG_PATH")
        .or_else(|| runtime_config_path(format!("node/node{node_id}/node_config.json")))
        .unwrap_or_else(|| {
            current_dir_join(format!(
                "src/node/node{node_id}/config/config_file/node_config.json"
            ))
        })
        .to_string_lossy()
        .into_owned()
}

pub fn user_config_path(user_id: u16) -> String {
    env_path("GSTBK_USER_CONFIG_PATH")
        .or_else(|| runtime_config_path(format!("user/user{user_id}/user_config.json")))
        .unwrap_or_else(|| {
            current_dir_join(format!(
                "src/user/user{user_id}/config/config_file/user_config.json"
            ))
        })
        .to_string_lossy()
        .into_owned()
}

pub fn node_info_path(node_id: u16, file_name: &str) -> PathBuf {
    env_path("GSTBK_NODE_INFO_DIR")
        .or_else(|| runtime_state_path(format!("node/node{node_id}/info")))
        .unwrap_or_else(|| current_dir_join(format!("src/node/node{node_id}/info")))
        .join(file_name)
}

pub fn user_info_path(user_id: u16, file_name: &str) -> PathBuf {
    env_path("GSTBK_USER_INFO_DIR")
        .or_else(|| runtime_state_path(format!("user/user{user_id}/info")))
        .unwrap_or_else(|| current_dir_join(format!("src/user/user{user_id}/info")))
        .join(file_name)
}

pub fn ensure_parent_dir(path: &Path) {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).unwrap();
    }
}
