package org.gstbk.chain;

public final class PersonalInfoClient {
    private PersonalInfoClient() {}

    public static void main(String[] args) throws Exception {
        new ContractCommandRunner(
            "PersonalInfo",
            "info",
            "infoJsonOrPath",
            "GSTBK_PERSONAL_INFO_CONTRACT_ADDRESS"
        ).run(args);
    }
}
