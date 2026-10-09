use crate::messages::user::sign_msg::SignPhaseStartFlag;
use curv::{
    cryptographic_primitives::hashing::DigestExt,
    elliptic::curves::{Bls12_381_1, Bls12_381_2, Point, Scalar},
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;

use crate::params::Sigma;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProxyToNodesVerifyPhaseBroadcastMsg {
    pub sender: u16,
    pub user_id: u16,
    pub role: String,
    // pub sigma:Sigma,
    // pub msg_user:SignPhaseStartFlag,
}
