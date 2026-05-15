use curv::elliptic::curves::{Bls12_381_1, Point, Scalar};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::net::{TcpListener, TcpStream};

use class_group::primitives::cl_dl_public_setup::*;
use gs_tbk_scheme::messages::proxy::join_issue_msg::UserInfo;
use gs_tbk_scheme::messages::proxy::revoke_msg::RevokeInfo;
use gs_tbk_scheme::params::{EiInfo, Gpk, Reg, RL};
use gs_tbk_scheme::tree::{Tree, TreeNode};
use gs_tbk_scheme::{messages::proxy::setup_msg::NodeInfo, params::ThreasholdParam};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Proxy {
    pub id: u16,
    pub role: String,
    pub group: CLGroup,
    pub address: String,
    pub tree: Tree,
    pub threashold_param: ThreasholdParam,
    pub gpk: Option<Gpk>,
    pub node_info_vec: Option<Vec<NodeInfo>>,
    pub user_info_map: Option<HashMap<u16, UserInfo>>,
    pub participants: Option<Vec<u16>>,
    pub revoke_info: Option<RevokeInfo>,
    pub ei_info: Option<EiInfo>,
    pub rl: Option<RL>,
}
