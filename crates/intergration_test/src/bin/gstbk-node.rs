use anyhow::{bail, Result};
use std::env;

fn usage() -> &'static str {
    "Usage: gstbk-node <1|2|3|4>"
}

fn main() -> Result<()> {
    let mut args = env::args().skip(1);
    let Some(node_id) = args.next() else {
        bail!(usage());
    };
    if args.next().is_some() {
        bail!(usage());
    }

    match node_id.as_str() {
        "1" => intergration_test::node::node1::node1::main(),
        "2" => intergration_test::node::node2::node2::main(),
        "3" => intergration_test::node::node3::node3::main(),
        "4" => intergration_test::node::node4::node4::main(),
        _ => bail!(usage()),
    }
}
