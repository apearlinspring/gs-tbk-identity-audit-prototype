use curv::{
    cryptographic_primitives::hashing::DigestExt,
    elliptic::curves::{Bls12_381_1, Bls12_381_2, Point, Scalar},
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;

use crate::params::{EiInfo, RevokePhaseSignSharedMessageType, RL};

use crate::tree::Tau;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TreeNodeBaseInfo {
    pub base_j: Point<Bls12_381_1>,
    pub zeta_j: Scalar<Bls12_381_1>,
    pub v_j: Scalar<Bls12_381_1>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxyToNodesRevokePhaseOneBroadcastMsg {
    pub sender: u16,
    pub role: String,
    pub leaf_node_id: usize,
    pub t: Tau,
    pub base_info_map: HashMap<usize, TreeNodeBaseInfo>,
    pub user_id: u16,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RevokeInfo {
    pub leaf_node_id: usize,
    pub t: Tau,
    pub yt: Scalar<Bls12_381_1>,
    pub h_sim_t: Point<Bls12_381_1>,
    pub h_hat_t: Point<Bls12_381_2>,
    pub leaf_node_base_info_map: HashMap<usize, TreeNodeBaseInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxyToNodesRevokePhaseTwoBroadcastMsg {
    pub sender: u16,
    pub role: String,
    pub ei_info: EiInfo,
    //pub rl:RL,
    pub user_id: u16,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxyToUserRevokePhaseBroadcastMsg {
    pub sender: u16,
    pub role: String,
    pub ei_info: EiInfo,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NodeUserRevokeSignSharedMessage {
    pub shared_message_map: HashMap<u16, Vec<RevokePhaseSignSharedMessageType>>,
}
