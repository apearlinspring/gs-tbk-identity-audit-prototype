use crate::params::PKHex;
use class_group::primitives::cl_dl_public_setup::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NodeInfo {
    pub id: u16, // assigned id
    pub pk_hex: PKHex,
    pub address: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxySetupPhaseBroadcastMsg {
    pub node_info_vec: Vec<NodeInfo>,
    pub tree: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxySetupPhaseFinishFlag {
    pub sender: u16,
    pub role: String,
}
