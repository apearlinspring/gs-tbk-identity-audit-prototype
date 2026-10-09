#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_DIR="${1:-"$APP_DIR/../../contracts/fisco-bcos"}"
OUTPUT_DIR="${2:-"$APP_DIR/src/main/java"}"
PACKAGE_NAME="${GSTBK_WRAPPER_PACKAGE:-org.gstbk.chain.contracts}"
CONSOLE_DIR="${FISCO_CONSOLE_DIR:-"$HOME/fisco/console"}"

if [[ ! -d "$CONSOLE_DIR/lib" || ! -f "$CONSOLE_DIR/apps/console.jar" ]]; then
    echo "FISCO console not found. Set FISCO_CONSOLE_DIR to the console directory." >&2
    exit 2
fi

for contract in PersonalInfo Signature Table; do
    if [[ ! -f "$CONTRACT_DIR/$contract.sol" ]]; then
        echo "Missing contract source: $CONTRACT_DIR/$contract.sol" >&2
        exit 2
    fi
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/classes"

cat >"$TMP_DIR/GenerateWrappers.java" <<'JAVA'
import console.contract.model.AbiAndBin;
import console.contract.utils.ContractCompiler;
import org.fisco.bcos.codegen.v3.wrapper.ContractWrapper;

public class GenerateWrappers {
    public static void main(String[] args) throws Exception {
        if (args.length < 4 || args.length % 2 != 0) {
            throw new IllegalArgumentException(
                "usage: GenerateWrappers outputDir packageName contractName solPath..."
            );
        }

        String outputDir = args[0];
        String packageName = args[1];
        ContractWrapper wrapper = new ContractWrapper(false);

        for (int i = 2; i < args.length; i += 2) {
            String contractName = args[i];
            String solPath = args[i + 1];
            AbiAndBin compiled = ContractCompiler.compileContract(solPath, contractName, false, false);
            String smBin = compiled.getSmBin();
            if (smBin == null || smBin.isEmpty()) {
                smBin = compiled.getBin();
            }
            wrapper.generateJavaFiles(
                contractName,
                compiled.getBin(),
                smBin,
                compiled.getAbi(),
                outputDir,
                packageName,
                false,
                0
            );
        }
    }
}
JAVA

(
    cd "$CONSOLE_DIR"
    javac -encoding UTF-8 -cp "apps/console.jar:lib/*" -d "$TMP_DIR/classes" \
        "$TMP_DIR/GenerateWrappers.java"
    java -cp "$TMP_DIR/classes:apps/console.jar:lib/*" GenerateWrappers \
        "$OUTPUT_DIR" \
        "$PACKAGE_NAME" \
        PersonalInfo "$CONTRACT_DIR/PersonalInfo.sol" \
        Signature "$CONTRACT_DIR/Signature.sol"
)

echo "Generated wrappers under $OUTPUT_DIR/${PACKAGE_NAME//.//}"
