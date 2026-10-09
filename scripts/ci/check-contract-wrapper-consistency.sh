#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
contracts_dir="$root_dir/contracts/fisco-bcos"
sdk_dir="$root_dir/chain-apps/fisco-bcos-java-sdk"
java_dir="$sdk_dir/src/main/java/org/gstbk/chain"
wrapper_dir="$java_dir/contracts"
build_gradle="$sdk_dir/build.gradle"
generated_tmp_dir=""

cleanup() {
  if [[ -n "$generated_tmp_dir" ]]; then
    rm -rf "$generated_tmp_dir"
  fi
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  local description="$2"

  if [[ ! -f "$path" ]]; then
    fail "Missing $description: $path"
  fi
}

require_fixed() {
  local path="$1"
  local needle="$2"
  local description="$3"

  if ! grep -Fq -- "$needle" "$path"; then
    fail "Missing $description in $path"
  fi
}

require_regex() {
  local path="$1"
  local pattern="$2"
  local description="$3"

  if ! grep -Eq -- "$pattern" "$path"; then
    fail "Missing $description in $path"
  fi
}

require_compact_regex() {
  local path="$1"
  local pattern="$2"
  local description="$3"

  if ! tr '\n' ' ' <"$path" | grep -Eq -- "$pattern"; then
    fail "Missing $description in $path"
  fi
}

check_contract_pair() {
  local contract="$1"
  local value_field="$2"
  local table_name="$3"
  local runner_script="$4"
  local gradle_task="$5"
  local client_class="$6"
  local value_label="$7"
  local value_argument="$8"
  local address_env="$9"

  local contract_file="$contracts_dir/$contract.sol"
  local wrapper_file="$wrapper_dir/$contract.java"
  local client_file="$java_dir/$client_class.java"
  local runner_file="$sdk_dir/$runner_script"

  require_file "$contract_file" "$contract contract source"
  require_file "$wrapper_file" "$contract Java wrapper"
  require_file "$client_file" "$client_class runner client"
  require_file "$runner_file" "$runner_script runner script"

  require_regex "$contract_file" "contract[[:space:]]+$contract([[:space:]]|\\{)" "$contract Solidity contract declaration"
  require_fixed "$contract_file" "string constant tableName = \"$table_name\";" "$contract table name $table_name"
  require_fixed "$contract_file" "tm.createKVTable(tableName, \"user\", \"$value_field\");" "$contract KVTable schema"
  require_compact_regex "$contract_file" "function[[:space:]]+register[[:space:]]*\\([^)]*string[[:space:]]+memory[[:space:]]+user[^)]*string[[:space:]]+memory[[:space:]]+$value_field[^)]*\\)[^{;]*returns[[:space:]]*\\([[:space:]]*int256[[:space:]]*\\)" "$contract register(user, $value_field) ABI shape"
  require_compact_regex "$contract_file" "function[[:space:]]+select[[:space:]]*\\([^)]*string[[:space:]]+memory[[:space:]]+user[^)]*\\)[^{;]*returns[[:space:]]*\\([[:space:]]*bool[[:space:]]*,[[:space:]]*string[[:space:]]+memory[[:space:]]*\\)" "$contract select(user) ABI shape"
  require_compact_regex "$contract_file" "function[[:space:]]+selectWithBlockNumber[[:space:]]*\\([^)]*string[[:space:]]+memory[[:space:]]+user[^)]*uint256[[:space:]]+block_number[^)]*\\)[^{;]*returns[[:space:]]*\\([[:space:]]*int256[[:space:]]*,[[:space:]]*string[[:space:]]+memory[[:space:]]*\\)" "$contract selectWithBlockNumber(user, block_number) ABI shape"

  require_regex "$wrapper_file" "public[[:space:]]+class[[:space:]]+$contract[[:space:]]+extends[[:space:]]+Contract" "$contract wrapper class declaration"
  require_fixed "$wrapper_file" "public static final String[] ABI_ARRAY" "$contract wrapper ABI_ARRAY"
  require_fixed "$wrapper_file" '\"name\":\"register\"' "$contract wrapper ABI register entry"
  require_fixed "$wrapper_file" '\"name\":\"select\"' "$contract wrapper ABI select entry"
  require_fixed "$wrapper_file" '\"name\":\"selectWithBlockNumber\"' "$contract wrapper ABI selectWithBlockNumber entry"
  require_fixed "$wrapper_file" "\\\"name\\\":\\\"$value_field\\\"" "$contract wrapper ABI value field $value_field"
  require_fixed "$wrapper_file" "public static final String FUNC_REGISTER = \"register\";" "$contract wrapper register constant"
  require_fixed "$wrapper_file" "public static final String FUNC_SELECT = \"select\";" "$contract wrapper select constant"
  require_fixed "$wrapper_file" "public static final String FUNC_SELECTWITHBLOCKNUMBER = \"selectWithBlockNumber\";" "$contract wrapper selectWithBlockNumber constant"
  require_compact_regex "$wrapper_file" "public[[:space:]]+TransactionReceipt[[:space:]]+register[[:space:]]*\\([[:space:]]*String[[:space:]]+user[[:space:]]*,[[:space:]]*String[[:space:]]+$value_field[[:space:]]*\\)" "$contract wrapper register method"
  require_compact_regex "$wrapper_file" "public[[:space:]]+Tuple2<[^>]+>[[:space:]]+select[[:space:]]*\\([[:space:]]*String[[:space:]]+user[[:space:]]*\\)" "$contract wrapper select method"
  require_compact_regex "$wrapper_file" "public[[:space:]]+Tuple2<[^>]*BigInteger[^>]*String[^>]*>[[:space:]]+selectWithBlockNumber[[:space:]]*\\([[:space:]]*String[[:space:]]+user[[:space:]]*,[[:space:]]*BigInteger[[:space:]]+block_number[[:space:]]*\\)" "$contract wrapper selectWithBlockNumber method"
  require_compact_regex "$wrapper_file" "public[[:space:]]+static[[:space:]]+$contract[[:space:]]+load[[:space:]]*\\(" "$contract wrapper load method"
  require_compact_regex "$wrapper_file" "public[[:space:]]+static[[:space:]]+$contract[[:space:]]+deploy[[:space:]]*\\(" "$contract wrapper deploy method"

  require_regex "$client_file" "public[[:space:]]+final[[:space:]]+class[[:space:]]+$client_class" "$client_class declaration"
  require_fixed "$client_file" "\"$contract\"," "$client_class contract binding"
  require_fixed "$client_file" "\"$value_label\"," "$client_class output label"
  require_fixed "$client_file" "\"$value_argument\"," "$client_class value argument name"
  require_fixed "$client_file" "\"$address_env\"" "$client_class address environment variable"

  require_fixed "$runner_file" "set -euo pipefail" "$runner_script strict mode"
  require_fixed "$runner_file" "$gradle_task --args=" "$runner_script Gradle task $gradle_task"
  require_compact_regex "$build_gradle" "tasks\\.register\\(\"$gradle_task\",[[:space:]]*JavaExec\\).*mainClass[[:space:]]*=[[:space:]]*\"org\\.gstbk\\.chain\\.$client_class\"" "Gradle task $gradle_task for $client_class"
}

check_common_invocation_layer() {
  local invoker_file="$java_dir/ContractInvoker.java"
  local command_runner_file="$java_dir/ContractCommandRunner.java"
  local generator_file="$sdk_dir/scripts/generate-contract-wrappers.sh"

  require_file "$build_gradle" "Java SDK build.gradle"
  require_file "$invoker_file" "ContractInvoker"
  require_file "$command_runner_file" "ContractCommandRunner"
  require_file "$generator_file" "wrapper generation script"

  require_fixed "$invoker_file" 'private static final String CONTRACT_PACKAGE = "org.gstbk.chain.contracts";' "ContractInvoker wrapper package"
  require_fixed "$invoker_file" 'getMethod("register", String.class, String.class)' "ContractInvoker register reflection"
  require_fixed "$invoker_file" 'getMethod("select", String.class)' "ContractInvoker select reflection"
  require_fixed "$invoker_file" 'getMethod("selectWithBlockNumber", String.class, BigInteger.class)' "ContractInvoker selectWithBlockNumber reflection"

  require_fixed "$command_runner_file" 'case "register":' "ContractCommandRunner register command"
  require_fixed "$command_runner_file" 'case "select":' "ContractCommandRunner select command"
  require_fixed "$command_runner_file" 'case "history":' "ContractCommandRunner history command"
  require_fixed "$command_runner_file" "Payload arguments may be compact JSON" "ContractCommandRunner payload help"

  require_fixed "$generator_file" "PersonalInfo \"\$CONTRACT_DIR/PersonalInfo.sol\"" "wrapper generator PersonalInfo source"
  require_fixed "$generator_file" "Signature \"\$CONTRACT_DIR/Signature.sol\"" "wrapper generator Signature source"
}

run_optional_generated_wrapper_diff() {
  if [[ "${GSTBK_CHECK_GENERATED_WRAPPERS:-0}" != "1" ]]; then
    echo "Optional generated-wrapper diff skipped; set GSTBK_CHECK_GENERATED_WRAPPERS=1 with FISCO_CONSOLE_DIR to enable it."
    return
  fi

  if [[ -z "${FISCO_CONSOLE_DIR:-}" ]]; then
    fail "GSTBK_CHECK_GENERATED_WRAPPERS=1 requires FISCO_CONSOLE_DIR"
  fi

  if [[ ! -d "$FISCO_CONSOLE_DIR/lib" || ! -f "$FISCO_CONSOLE_DIR/apps/console.jar" ]]; then
    fail "FISCO console not found under FISCO_CONSOLE_DIR=$FISCO_CONSOLE_DIR"
  fi

  generated_tmp_dir="$(mktemp -d)"
  local output_dir="$generated_tmp_dir/src/main/java"

  bash "$sdk_dir/scripts/generate-contract-wrappers.sh" "$contracts_dir" "$output_dir"

  for contract in PersonalInfo Signature; do
    local generated_file="$output_dir/org/gstbk/chain/contracts/$contract.java"
    require_file "$generated_file" "generated $contract wrapper"
    if ! diff -u "$wrapper_dir/$contract.java" "$generated_file"; then
      fail "Generated wrapper differs from committed wrapper: $contract"
    fi
  done

  echo "Optional generated-wrapper diff passed."
}

require_file "$contracts_dir/Table.sol" "Table contract source"
require_regex "$contracts_dir/Table.sol" "contract[[:space:]]+TableManager|interface[[:space:]]+TableManager" "TableManager declaration"
require_regex "$contracts_dir/Table.sol" "contract[[:space:]]+KVTable|interface[[:space:]]+KVTable" "KVTable declaration"

check_common_invocation_layer
check_contract_pair "PersonalInfo" "info" "u_info" "info_run.sh" "personalInfo" "PersonalInfoClient" "info" "infoJsonOrPath" "GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS"
check_contract_pair "Signature" "signatures" "u_signatures" "signature_run.sh" "signature" "SignatureClient" "signature" "signatureJsonOrPath" "GSTBK_SIGNATURE_CONTRACT_ADDRESS"
run_optional_generated_wrapper_diff

echo "Contract-wrapper consistency checks passed."
