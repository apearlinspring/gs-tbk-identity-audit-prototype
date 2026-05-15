use curv::arithmetic::traits::*;
use curv::BigInt;

use crate::id_encode::*;
use crate::params::*;
use cl_encrypt::cl::clwarpper::*;
use std::env;
use std::path::{Path, PathBuf};

const DEFAULT_CL_KEYPAIR_PATH: &str = "./cl_keypair.json";

pub fn cl_key_pair_gen() {
    cl_key_pair_gen_to(cl_keypair_path()).unwrap();
}

pub fn cl_key_pair_gen_to(path: impl AsRef<Path>) -> std::io::Result<()> {
    let bound =
        BigInt::from_str_radix("519825222697581994973081647134787959795934971297792", 10).unwrap();
    let cl_sk = BigInt::sample_range(&BigInt::from(0), &bound).to_string();
    //计算公钥
    let cl_pk = public_key_gen(cl_sk.clone());
    let cl_keypair = CLKeypair {
        sk: cl_sk,
        pk: cl_pk,
    };
    let cl_keypair_json = serde_json::to_string(&cl_keypair).unwrap();
    std::fs::write(path, cl_keypair_json)
}

pub fn encrypt_prove(info: PersonalInfo) -> BlockPersonalInfo {
    try_encrypt_prove(info).unwrap_or_else(|err| panic!("encrypt_prove failed: {err}"))
}

pub fn try_encrypt_prove(info: PersonalInfo) -> Result<BlockPersonalInfo, String> {
    let business_encoded = encode_personal_info(&info.id_info)
        .map_err(|err| format!("failed to encode personal identity fields: {err}"))?;
    let cl_plaintext = identity_business_encoding_to_cl_plaintext(&business_encoded)
        .map_err(|err| format!("failed to map identity encoding to CL plaintext: {err}"))?;
    let commit_str =
        power_of_h_checked(&cl_plaintext).map_err(|err| format!("native CL call failed: {err}"))?;
    let cl_keypair: CLKeypair = try_read_cl_keypair()?;
    let coefficients_bound =
        BigInt::from_str_radix("519825222697581994973081647134787959795934971297792", 10).unwrap();
    let random_str = BigInt::sample_below(&coefficients_bound.clone()).to_string();
    let id_enc = encrypt_enc(
        cl_keypair.pk.clone(),
        cl_plaintext.clone(),
        random_str.clone(),
    );
    let id_proof = cl_enc_com_prove(
        cl_keypair.pk,
        id_enc.clone(),
        commit_str.clone(),
        cl_plaintext,
        random_str,
    );
    Ok(BlockPersonalInfo {
        id_enc,
        zkp_proof: id_proof,
        commitment: commit_str,
        other_info: info.other_info,
    })
}

pub fn decrypt_verify(info: BlockPersonalInfo) {
    if verify_block_personal_info(&info).unwrap_or(false) {
        println!("哟西，验证通过");
    }
}

pub fn verify_block_personal_info(info: &BlockPersonalInfo) -> Result<bool, String> {
    let cl_keypair: CLKeypair = try_read_cl_keypair()?;
    let proof_verify_result = cl_enc_com_verify(
        info.zkp_proof.clone(),
        cl_keypair.pk,
        info.id_enc.clone(),
        info.commitment.clone(),
    );

    Ok(proof_verify_result == "true")
}

#[cfg(test)]
fn write_block_info_to_runtime(block_info: &BlockPersonalInfo) {
    let Some(runtime_dir) = env::var_os("GSTBK_RUNTIME_DIR") else {
        return;
    };

    let runtime_dir = PathBuf::from(runtime_dir);
    std::fs::create_dir_all(&runtime_dir).unwrap();
    let output_path = runtime_dir.join("block_personal_info.json");
    let block_info_json = serde_json::to_string(block_info).unwrap();
    std::fs::write(&output_path, block_info_json).unwrap();
    println!("blockPersonalInfoPath {}", output_path.display());
}

#[cfg(test)]
fn ensure_cl_keypair_for_test() {
    let path = cl_keypair_path();
    if path.exists() {
        return;
    }

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).unwrap();
    }
    cl_key_pair_gen_to(&path).unwrap();
}

fn cl_keypair_path() -> PathBuf {
    env::var_os("GSTBK_CL_KEYPAIR_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(DEFAULT_CL_KEYPAIR_PATH))
}

fn try_read_cl_keypair() -> Result<CLKeypair, String> {
    let path = cl_keypair_path();
    let contents = std::fs::read_to_string(&path).map_err(|err| {
        format!(
            "failed to read CL keypair from {}: {}. Set GSTBK_CL_KEYPAIR_PATH or run keygen first",
            path.display(),
            err
        )
    })?;
    serde_json::from_str(&contents).map_err(|err| {
        format!(
            "failed to parse CL keypair from {}: {}",
            path.display(),
            err
        )
    })
}

#[test]
fn test() {
    let bound =
        BigInt::from_str_radix("519825222697581994973081647134787959795934971297792", 10).unwrap();
    let sk = BigInt::sample_range(&BigInt::from(0), &bound).to_string();

    //计算公钥
    let pk = public_key_gen(sk.clone());
    //加密
    let random = BigInt::sample_range(&BigInt::from(0), &bound).to_string();
    let msg = "123".to_string();
    let cipher = encrypt_enc(pk.clone(), msg, random.clone());
    println!("cipher: {}", cipher);

    let m = decrypt_enc(sk.to_string(), cipher.clone());
    println!("m: {}", m);
}

#[test]
pub fn keygen() {
    cl_key_pair_gen();
}

#[test]
pub fn enc_prove_test() {
    ensure_cl_keypair_for_test();

    let info = PersonalInfo {
        id_info: IDInfo {
            name: String::from("测试用户"),
            id: String::from("000000200001010000"),
        },
        other_info: OtherInfo {
            behaivor: String::from("缴纳税务"),
            agency: String::from("文昌市税务局"),
            time: String::from("2024.5.16"),
            location: String::from("海南省 海口市 文昌市"),
        },
    };

    let block_info = encrypt_prove(info);

    write_block_info_to_runtime(&block_info);
    decrypt_verify(block_info);
}

#[test]
pub fn try_encrypt_prove_reports_business_encoding_failure() {
    let info = PersonalInfo {
        id_info: IDInfo {
            name: String::from("Alice"),
            id: String::from("00000020000101001Z"),
        },
        other_info: OtherInfo {
            behaivor: String::from("demo"),
            agency: String::from("demo"),
            time: String::from("2026-05-11"),
            location: String::from("demo"),
        },
    };

    let result = try_encrypt_prove(info);
    assert!(result.is_err());
    let err = result.err().unwrap();
    assert!(err.contains("failed to encode personal identity fields"));
    assert!(err.contains("identity id check digit"));
}

#[test]
pub fn block_personal_info_json_keeps_expected_fields_and_strings() {
    let block_info = BlockPersonalInfo {
        id_enc: String::from("ciphertext-demo"),
        zkp_proof: String::from("proof-demo"),
        commitment: String::from("commitment-demo"),
        other_info: OtherInfo {
            behaivor: String::from("缴纳税务"),
            agency: String::from("文昌市税务局"),
            time: String::from("2024.5.16"),
            location: String::from("海南省 海口市 文昌市"),
        },
    };

    let json = serde_json::to_string(&block_info).unwrap();
    assert_eq!(
        json,
        "{\"id_enc\":\"ciphertext-demo\",\"zkp_proof\":\"proof-demo\",\"commitment\":\"commitment-demo\",\"other_info\":{\"behaivor\":\"缴纳税务\",\"agency\":\"文昌市税务局\",\"time\":\"2024.5.16\",\"location\":\"海南省 海口市 文昌市\"}}"
    );

    let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed["id_enc"], "ciphertext-demo");
    assert_eq!(parsed["zkp_proof"], "proof-demo");
    assert_eq!(parsed["commitment"], "commitment-demo");
    assert_eq!(parsed["other_info"]["agency"], "文昌市税务局");
}
