use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct IDInfo {
    pub id: String,
    pub name: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OtherInfo {
    pub behaivor: String,
    pub agency: String,
    pub time: String,
    pub location: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PersonalInfo {
    pub id_info: IDInfo,
    pub other_info: OtherInfo,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BlockPersonalInfo {
    pub id_enc: String,
    pub zkp_proof: String,
    pub commitment: String,
    pub other_info: OtherInfo,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CLKeypair {
    pub sk: String,
    pub pk: String,
}
