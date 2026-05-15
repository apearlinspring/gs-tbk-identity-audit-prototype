use id_info_process::id_process::{
    cl_key_pair_gen_to, try_encrypt_prove, verify_block_personal_info,
};
use id_info_process::params::{BlockPersonalInfo, PersonalInfo};
use std::env;
use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    if let Err(err) = run() {
        eprintln!("error: {err}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args_os();
    let _bin = args.next();
    let Some(command) = args.next() else {
        return Err(usage());
    };
    let remaining: Vec<OsString> = args.collect();

    match command.to_string_lossy().as_ref() {
        "keygen" => keygen(&remaining),
        "enc" => enc(&remaining),
        "verify" | "decrypt" => verify(&remaining),
        _ => Err(usage()),
    }
}

fn keygen(args: &[OsString]) -> Result<(), String> {
    let output = parse_path_arg(args, "--output")?
        .or_else(|| env_path("GSTBK_CL_KEYPAIR_PATH"))
        .unwrap_or_else(|| runtime_path("cl_keypair.json"));

    create_parent_dir(&output)?;
    cl_key_pair_gen_to(&output)
        .map_err(|err| format!("failed to write CL keypair to {}: {err}", output.display()))?;
    println!("clKeypairPath {}", output.display());
    Ok(())
}

fn enc(args: &[OsString]) -> Result<(), String> {
    let input = parse_path_arg(args, "--input")?
        .or_else(|| env_path("GSTBK_ID_INFO_INPUT_PATH"))
        .ok_or_else(|| format!("missing --input <json>\n{}", usage()))?;
    let output = parse_path_arg(args, "--output")?
        .or_else(|| env_path("GSTBK_ID_INFO_OUTPUT_PATH"))
        .unwrap_or_else(|| runtime_path("block_personal_info.json"));

    let info: PersonalInfo = read_json(&input)?;
    let block_info = try_encrypt_prove(info)?;
    create_parent_dir(&output)?;
    write_json_pretty(&output, &block_info)?;
    println!("idInfoInputPath {}", input.display());
    println!("blockPersonalInfoPath {}", output.display());
    Ok(())
}

fn verify(args: &[OsString]) -> Result<(), String> {
    let input = parse_path_arg(args, "--input")?
        .or_else(|| env_path("GSTBK_ID_INFO_OUTPUT_PATH"))
        .unwrap_or_else(|| runtime_path("block_personal_info.json"));

    let block_info: BlockPersonalInfo = read_json(&input)?;
    let verified = verify_block_personal_info(&block_info)?;
    println!("blockPersonalInfoPath {}", input.display());
    println!("verify {}", verified);
    if verified {
        Ok(())
    } else {
        Err(String::from(
            "identity ciphertext proof verification failed",
        ))
    }
}

fn parse_path_arg(args: &[OsString], flag: &str) -> Result<Option<PathBuf>, String> {
    let mut value = None;
    let mut index = 0;
    while index < args.len() {
        let arg = args[index].to_string_lossy();
        if arg == flag {
            let Some(path) = args.get(index + 1) else {
                return Err(format!("{flag} requires a path value"));
            };
            value = Some(PathBuf::from(path));
            index += 2;
        } else if arg == "--input" || arg == "--output" {
            if args.get(index + 1).is_none() {
                return Err(format!("{arg} requires a path value"));
            }
            index += 2;
        } else {
            return Err(format!("unexpected argument: {arg}\n{}", usage()));
        }
    }
    Ok(value)
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, String> {
    let contents = fs::read_to_string(path)
        .map_err(|err| format!("failed to read {}: {err}", path.display()))?;
    serde_json::from_str(&contents)
        .map_err(|err| format!("failed to parse JSON from {}: {err}", path.display()))
}

fn write_json_pretty<T: serde::Serialize>(path: &Path, value: &T) -> Result<(), String> {
    let json = serde_json::to_string_pretty(value)
        .map_err(|err| format!("failed to encode JSON for {}: {err}", path.display()))?;
    fs::write(path, json).map_err(|err| format!("failed to write {}: {err}", path.display()))
}

fn create_parent_dir(path: &Path) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .map_err(|err| format!("failed to create {}: {err}", parent.display()))?;
        }
    }
    Ok(())
}

fn env_path(name: &str) -> Option<PathBuf> {
    env::var_os(name).map(PathBuf::from)
}

fn runtime_path(file_name: &str) -> PathBuf {
    env_path("GSTBK_RUNTIME_DIR")
        .unwrap_or_else(|| PathBuf::from("runtime-state"))
        .join(file_name)
}

fn usage() -> String {
    String::from(
        "Usage:\n  id_info_process keygen [--output <json>]\n  id_info_process enc --input <json> [--output <json>]\n  id_info_process verify [--input <json>]",
    )
}
