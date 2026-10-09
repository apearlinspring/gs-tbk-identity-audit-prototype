package org.gstbk.chain;

public final class SignatureClient {
    private SignatureClient() {}

    public static void main(String[] args) throws Exception {
        new ContractCommandRunner(
            "Signature",
            "signature",
            "signatureJsonOrPath",
            "GSTBK_SIGNATURE_CONTRACT_ADDRESS"
        ).run(args);
    }
}
