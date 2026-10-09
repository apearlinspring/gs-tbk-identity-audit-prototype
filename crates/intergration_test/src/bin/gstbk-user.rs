use anyhow::{bail, Result};
use std::env;

fn usage() -> &'static str {
    "Usage: gstbk-user <1|2|3|4|5|6>"
}

fn main() -> Result<()> {
    let mut args = env::args().skip(1);
    let Some(user_id) = args.next() else {
        bail!(usage());
    };
    if args.next().is_some() {
        bail!(usage());
    }

    match user_id.as_str() {
        "1" => intergration_test::user::user1::user1::main(),
        "2" => intergration_test::user::user2::user2::main(),
        "3" => intergration_test::user::user3::user3::main(),
        "4" => intergration_test::user::user4::user4::main(),
        "5" => intergration_test::user::user5::user5::main(),
        "6" => intergration_test::user::user6::user6::main(),
        _ => bail!(usage()),
    }
}
