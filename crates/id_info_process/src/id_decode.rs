use crate::id_encode::CL_PLAINTEXT_PREFIX;
use crate::params::IDInfo;
use curv::arithmetic::Converter;
use curv::BigInt;
use std::error::Error;
use std::fmt;

#[derive(Debug)]
pub struct DecodeError(String);

impl fmt::Display for DecodeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::id_encode::encode_personal_info_for_cl_plaintext;

    #[test]
    fn chinese_identity_roundtrips_through_decimal_cl_plaintext() {
        assert_identity_roundtrip("测试用户一", "000000200001010019");
    }

    #[test]
    fn identity_with_x_check_digit_roundtrips_through_decimal_cl_plaintext() {
        assert_identity_roundtrip("测试用户二", "00000019491231002X");
    }

    #[test]
    fn non_ascii_name_roundtrips_through_decimal_cl_plaintext() {
        assert_identity_roundtrip("测试用户三", "000000200212120029");
    }

    #[test]
    fn invalid_identity_id_returns_clear_error() {
        let info = IDInfo {
            name: String::from("测试用户"),
            id: String::from("00000020000101001Z"),
        };
        let err = encode_personal_info_for_cl_plaintext(&info).unwrap_err();
        assert!(err.contains("identity id check digit"));
    }

    #[test]
    fn cl_plaintext_decoder_rejects_non_decimal_input() {
        let err = decode_personal_info_from_cl_plaintext("123ABC")
            .unwrap_err()
            .to_string();
        assert!(err.contains("only digits"));
    }

    fn assert_identity_roundtrip(name: &str, id: &str) {
        let info = IDInfo {
            name: String::from(name),
            id: String::from(id),
        };

        let decimal = encode_personal_info_for_cl_plaintext(&info).unwrap();
        assert!(decimal.bytes().all(|byte| byte.is_ascii_digit()));
        assert!(!decimal.is_empty());

        let decoded = decode_personal_info_from_cl_plaintext(&decimal).unwrap();
        assert_eq!(decoded.name, info.name);
        assert_eq!(decoded.id, info.id);
    }
}

impl Error for DecodeError {}

fn decode_char(c: char) -> Result<usize, DecodeError> {
    const CHARS: &str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    CHARS
        .find(c)
        .ok_or_else(|| DecodeError(format!("解码字符超出范围: {}", c)))
}

fn hex_to_utf8(hex_str: &str) -> Result<String, DecodeError> {
    let bytes: Result<Vec<u8>, _> = (0..hex_str.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex_str[i..i + 2], 16))
        .collect();

    match bytes {
        Ok(bytes) => {
            String::from_utf8(bytes).map_err(|_| DecodeError("UTF-8 解码错误".to_string()))
        }
        Err(_) => Err(DecodeError("解析十六进制字符串错误".to_string())),
    }
}

fn decompress_id(compressed_id: &str) -> Result<String, DecodeError> {
    if compressed_id.len() != 10 {
        return Err(DecodeError("压缩ID长度必须为10个字符".to_string()));
    }

    let mut id = String::new();

    let value1 = decode_char(compressed_id.chars().nth(0).unwrap())? * 36
        + decode_char(compressed_id.chars().nth(1).unwrap())?;
    id.push_str(&format!("{:03}", value1));

    let value2 = decode_char(compressed_id.chars().nth(2).unwrap())? * 36
        + decode_char(compressed_id.chars().nth(3).unwrap())?;
    id.push_str(&format!("{:03}", value2));

    let year_month_code = decode_char(compressed_id.chars().nth(4).unwrap())?;
    let (year_prefix, month) = if year_month_code >= 24 {
        (20, year_month_code - 24 + 1)
    } else if year_month_code >= 12 {
        (19, year_month_code - 12 + 1)
    } else {
        (0, year_month_code + 1)
    };
    id.push_str(&format!("{:02}", year_prefix));

    let day = decode_char(compressed_id.chars().nth(5).unwrap())?;
    let year_suffix = decode_char(compressed_id.chars().nth(6).unwrap())? * 36
        + decode_char(compressed_id.chars().nth(7).unwrap())?;
    let gender = year_suffix % 10;
    let year_suffix = year_suffix / 10;
    id.push_str(&format!("{:02}", year_suffix));
    id.push_str(&format!("{:02}", month));
    id.push_str(&format!("{:02}", day));

    let last_part = decode_char(compressed_id.chars().nth(8).unwrap())? * 36
        + decode_char(compressed_id.chars().nth(9).unwrap())?;
    let last_char = last_part / 100;
    let remaining = last_part % 100;

    id.push_str(&format!("{:02}", remaining));
    id.push_str(&format!("{}", gender));

    if last_char == 10 {
        id.push('X');
    } else {
        id.push_str(&format!("{}", last_char));
    }

    Ok(id)
}

pub fn decode_personal_info(encoded_str: &str) -> Result<IDInfo, DecodeError> {
    const COMPRESSED_ID_LENGTH: usize = 10;
    if encoded_str.len() <= COMPRESSED_ID_LENGTH {
        return Err(DecodeError("encoded identity is too short".to_string()));
    }

    let name_hex_length = encoded_str.len() - COMPRESSED_ID_LENGTH;
    if name_hex_length < 12 || name_hex_length > 36 || name_hex_length % 6 != 0 {
        return Err(DecodeError("姓名部分编码长度不正确".to_string()));
    }

    let name_hex = &encoded_str[..name_hex_length];
    let name = hex_to_utf8(name_hex)?;

    let compressed_id = &encoded_str[name_hex_length..];
    let id = decompress_id(compressed_id)?;

    Ok(IDInfo { name, id })
}

pub fn decode_personal_info_from_cl_plaintext(decimal: &str) -> Result<IDInfo, DecodeError> {
    if decimal.is_empty() {
        return Err(DecodeError(
            "CL plaintext decimal string must be non-empty".to_string(),
        ));
    }
    if !decimal.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(DecodeError(
            "CL plaintext decimal string must contain only digits".to_string(),
        ));
    }

    let bigint = BigInt::from_str_radix(decimal, 10)
        .map_err(|_| DecodeError("failed to parse CL plaintext decimal string".to_string()))?;
    let payload = String::from_utf8(BigInt::to_bytes(&bigint))
        .map_err(|_| DecodeError("CL plaintext bytes are not valid UTF-8".to_string()))?;
    let business_encoded = payload.strip_prefix(CL_PLAINTEXT_PREFIX).ok_or_else(|| {
        DecodeError(format!(
            "CL plaintext payload missing version prefix {CL_PLAINTEXT_PREFIX}"
        ))
    })?;
    decode_personal_info(business_encoded)
}

#[test]
fn test_decode_id() {
    let encoded_str = "e78e8be9babbe5ad90e7bc96e7a081EH0NYN15P0"; // 示例编码字符串
                                                                  // e78e8be9babbe5ad90e7bc96e7a081EH0NYN15P0

    match decode_personal_info(&encoded_str) {
        Ok(info) => println!("Decoded info: Name: {}, ID: {}", info.name, info.id),
        Err(e) => eprintln!("Error decoding info: {}", e),
    }
}
