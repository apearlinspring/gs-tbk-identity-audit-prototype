use crate::params::IDInfo;
use curv::arithmetic::Converter;
use curv::BigInt;

pub const CL_PLAINTEXT_PREFIX: &str = "GSTBK-ID-V1:";

pub fn encode_personal_info(info: &IDInfo) -> Result<String, String> {
    let encoded_name = utf8_to_hex(&info.name);
    let compressed_id = compress_id(&info.id)?;
    Ok(encoded_name + &compressed_id)
}

pub fn encode_personal_info_for_cl_plaintext(info: &IDInfo) -> Result<String, String> {
    let business_encoded = encode_personal_info(info)?;
    identity_business_encoding_to_cl_plaintext(&business_encoded)
}

pub fn identity_business_encoding_to_cl_plaintext(
    business_encoded: &str,
) -> Result<String, String> {
    if business_encoded.is_empty() {
        return Err("identity business encoding must be non-empty".to_string());
    }
    let payload = format!("{CL_PLAINTEXT_PREFIX}{business_encoded}");
    let decimal = BigInt::from_bytes(payload.as_bytes()).to_string();
    if decimal.bytes().all(|byte| byte.is_ascii_digit()) {
        Ok(decimal)
    } else {
        Err("CL plaintext mapping produced a non-decimal value".to_string())
    }
}

fn utf8_to_hex(utf8_str: &str) -> String {
    utf8_str
        .as_bytes()
        .iter()
        .map(|byte| format!("{:02x}", byte))
        .collect()
}

fn encode_char(value: usize) -> Result<char, String> {
    const CHARS: &str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    CHARS
        .chars()
        .nth(value)
        .ok_or_else(|| "base36 encode value out of range".to_string())
}

fn compress_id(id: &str) -> Result<String, String> {
    if id.len() != 18 {
        return Err("identity id must be 18 ASCII characters".to_string());
    }

    let mut encoded_id = String::new();

    let value1 = id[0..3]
        .parse::<usize>()
        .map_err(|_| "identity id region prefix must be numeric".to_string())?;
    encoded_id.push(encode_char(value1 / 36)?);
    encoded_id.push(encode_char(value1 % 36)?);

    let value2 = id[3..6]
        .parse::<usize>()
        .map_err(|_| "identity id region suffix must be numeric".to_string())?;
    encoded_id.push(encode_char(value2 / 36)?);
    encoded_id.push(encode_char(value2 % 36)?);

    let year_prefix = id[6..8]
        .parse::<usize>()
        .map_err(|_| "identity id year prefix must be numeric".to_string())?;
    let month = id[10..12]
        .parse::<usize>()
        .map_err(|_| "identity id month must be numeric".to_string())?;
    let year_month_code = if year_prefix == 19 {
        12 + month - 1
    } else if year_prefix == 20 {
        24 + month - 1
    } else {
        month - 1
    };
    encoded_id.push(encode_char(year_month_code)?);

    let day = id[12..14]
        .parse::<usize>()
        .map_err(|_| "identity id day must be numeric".to_string())?;
    encoded_id.push(encode_char(day)?);

    let year_suffix = id[8..10]
        .parse::<usize>()
        .map_err(|_| "identity id year suffix must be numeric".to_string())?;
    let gender = id[16..17]
        .parse::<usize>()
        .map_err(|_| "identity id gender digit must be numeric".to_string())?;
    let year_gender_code = year_suffix * 10 + gender;
    encoded_id.push(encode_char(year_gender_code / 36)?);
    encoded_id.push(encode_char(year_gender_code % 36)?);

    let last_char = if &id[17..18] == "X" {
        10
    } else {
        id[17..18]
            .parse::<usize>()
            .map_err(|_| "identity id check digit must be numeric or X".to_string())?
    };
    let last_part = last_char * 100
        + id[14..16]
            .parse::<usize>()
            .map_err(|_| "identity id sequence must be numeric".to_string())?;
    encoded_id.push(encode_char(last_part / 36)?);
    encoded_id.push(encode_char(last_part % 36)?);

    Ok(encoded_id)
}

#[test]
fn test_compress_id() {
    let info = IDInfo {
        name: String::from("测试编码用户"),
        id: String::from("000000200411230019"),
    };

    match encode_personal_info(&info) {
        Ok(encoded) => println!("Encoded info: {}", encoded),
        Err(e) => eprintln!("Error encoding info: {}", e),
    }
}
