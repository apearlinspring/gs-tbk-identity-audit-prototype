#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
contracts_dir="$root_dir/contracts/fisco-bcos"

required_files=(
  "Table.sol"
  "PersonalInfo.sol"
  "Signature.sol"
)

for file in "${required_files[@]}"; do
  path="$contracts_dir/$file"
  if [[ ! -f "$path" ]]; then
    echo "Missing contract source: $path" >&2
    exit 1
  fi
  if ! grep -Eq "pragma solidity" "$path"; then
    echo "Missing Solidity pragma: $path" >&2
    exit 1
  fi
done

grep -Eq "contract[[:space:]]+PersonalInfo" "$contracts_dir/PersonalInfo.sol"
grep -Eq "contract[[:space:]]+Signature" "$contracts_dir/Signature.sol"
grep -Eq "contract[[:space:]]+TableManager|interface[[:space:]]+TableManager" "$contracts_dir/Table.sol"
grep -Eq "contract[[:space:]]+KVTable|interface[[:space:]]+KVTable" "$contracts_dir/Table.sol"

echo "Solidity placeholder checks passed."
