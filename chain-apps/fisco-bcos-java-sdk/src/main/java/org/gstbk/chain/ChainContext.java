package org.gstbk.chain;

import java.math.BigInteger;
import java.nio.file.Files;
import java.nio.file.Path;
import org.fisco.bcos.sdk.v3.BcosSDK;
import org.fisco.bcos.sdk.v3.client.Client;
import org.fisco.bcos.sdk.v3.crypto.keypair.CryptoKeyPair;

final class ChainContext implements AutoCloseable {
    private static final String DEFAULT_CONFIG = "conf/config.toml";
    private static final String DEFAULT_GROUP = "group0";

    private final BcosSDK sdk;
    private final Client client;
    private final CryptoKeyPair keyPair;

    private ChainContext(BcosSDK sdk, Client client, CryptoKeyPair keyPair) {
        this.sdk = sdk;
        this.client = client;
        this.keyPair = keyPair;
    }

    static ChainContext load() {
        String configPath = System.getProperty(
            "fisco.config",
            System.getenv().getOrDefault("FISCO_CONFIG", DEFAULT_CONFIG)
        );
        if (!Files.exists(Path.of(configPath))) {
            throw new IllegalStateException("FISCO config not found: " + configPath);
        }

        String group = System.getProperty(
            "fisco.group",
            System.getenv().getOrDefault("FISCO_GROUP", DEFAULT_GROUP)
        );
        BcosSDK sdk = BcosSDK.build(configPath);
        Client client = sdk.getClient(group);
        CryptoKeyPair keyPair = client.getCryptoSuite().getCryptoKeyPair();
        return new ChainContext(sdk, client, keyPair);
    }

    Client client() {
        return client;
    }

    CryptoKeyPair keyPair() {
        return keyPair;
    }

    BigInteger blockNumber() {
        return client.getBlockNumber().getBlockNumber();
    }

    @Override
    public void close() {
        sdk.stopAll();
    }
}
