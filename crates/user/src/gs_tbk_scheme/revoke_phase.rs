use curv::{
    cryptographic_primitives::hashing::DigestExt,
    elliptic::curves::{Bls12_381_1, Bls12_381_2, Point, Scalar},
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;

use crate::user::User;
use gs_tbk_scheme::messages::proxy::revoke_msg::ProxyToUserRevokePhaseBroadcastMsg;
use gs_tbk_scheme::messages::user::revoke_msg::RevokePhaseStartFlag;

impl User {
    pub fn revoke_phase_start_flag(&self) -> RevokePhaseStartFlag {
        RevokePhaseStartFlag {
            sender: self.id.unwrap(),
            role: self.role.clone(),
        }
    }

    pub fn revoke_phase(&mut self, msg: &ProxyToUserRevokePhaseBroadcastMsg) {
        self.ei_info = Some(msg.ei_info.clone());
    }
}
