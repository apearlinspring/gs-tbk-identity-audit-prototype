package org.gstbk.chain;

import com.google.gson.Gson;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;
import java.io.IOException;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.util.Locale;
import org.fisco.bcos.sdk.v3.model.TransactionReceipt;

final class ContractCommandRunner {
    private static final Gson GSON = new Gson();

    private final String contractName;
    private final String valueLabel;
    private final String valueArgumentName;
    private final String addressEnvName;

    ContractCommandRunner(
            String contractName,
            String valueLabel,
            String valueArgumentName,
            String addressEnvName) {
        this.contractName = contractName;
        this.valueLabel = valueLabel;
        this.valueArgumentName = valueArgumentName;
        this.addressEnvName = addressEnvName;
    }

    void run(String[] args) throws Exception {
        if (args.length == 0) {
            usage();
            return;
        }

        try (ChainContext context = ChainContext.load()) {
            String command = args[0].toLowerCase(Locale.ROOT);
            switch (command) {
                case "blocknumber":
                case "getblocknumber":
                    requireArgs(args, 1);
                    System.out.println("blockNumber " + context.blockNumber());
                    break;
                case "deploy":
                    requireArgs(args, 1);
                    deploy(context);
                    break;
                case "register":
                    register(context, args);
                    break;
                case "select":
                case "query":
                    select(context, args);
                    break;
                case "history":
                case "selectwithblocknumber":
                    history(context, args);
                    break;
                default:
                    usage();
                    throw new IllegalArgumentException("Unsupported command: " + args[0]);
            }
        }
    }

    private void deploy(ChainContext context) throws Exception {
        Object contract = ContractInvoker.deploy(contractName, context);
        System.out.println("contractAddress " + ContractInvoker.contractAddress(contract));
        System.out.println("blockNumber " + context.blockNumber());
    }

    private void register(ChainContext context, String[] args) throws Exception {
        String contractAddress;
        String user;
        String value;
        if (args.length == 4) {
            contractAddress = args[1];
            user = args[2];
            value = readValue(args[3]);
        } else if (args.length == 3) {
            contractAddress = requireAddressFromEnv();
            user = args[1];
            value = readValue(args[2]);
        } else {
            usage();
            throw new IllegalArgumentException(
                "register expects either 2 or 3 arguments after the command"
            );
        }

        Object contract = ContractInvoker.load(contractName, contractAddress, context);
        ContractInvoker.RegisterResult result = ContractInvoker.register(contract, user, value);
        printReceipt(result);
        printValue(value);
    }

    private void select(ChainContext context, String[] args) throws Exception {
        String contractAddress;
        String user;
        if (args.length == 3) {
            contractAddress = args[1];
            user = args[2];
        } else if (args.length == 2) {
            contractAddress = requireAddressFromEnv();
            user = args[1];
        } else {
            usage();
            throw new IllegalArgumentException(
                "select/query expects either 1 or 2 arguments after the command"
            );
        }

        Object contract = ContractInvoker.load(contractName, contractAddress, context);
        ContractInvoker.SelectResult result = ContractInvoker.select(contract, user);
        System.out.println("exists " + result.exists());
        printValue(result.exists() ? result.value() : "");
    }

    private void history(ChainContext context, String[] args) throws Exception {
        String contractAddress;
        String user;
        BigInteger blockNumber;
        if (args.length == 4) {
            contractAddress = args[1];
            user = args[2];
            blockNumber = new BigInteger(args[3]);
        } else if (args.length == 3) {
            contractAddress = requireAddressFromEnv();
            user = args[1];
            blockNumber = new BigInteger(args[2]);
        } else {
            usage();
            throw new IllegalArgumentException(
                "history expects either 2 or 3 arguments after the command"
            );
        }

        Object contract = ContractInvoker.load(contractName, contractAddress, context);
        ContractInvoker.HistoryResult result =
            ContractInvoker.selectWithBlockNumber(contract, user, blockNumber);
        System.out.println("ret " + result.retCode());
        printValue(result.value());
    }

    private void printReceipt(ContractInvoker.RegisterResult result) {
        if (result.retCode() != null) {
            System.out.println("ret " + result.retCode());
        }

        TransactionReceipt receipt = result.receipt();
        if (receipt == null) {
            throw new IllegalStateException("No transaction receipt returned");
        }

        System.out.println("status " + receipt.getStatus());
        if (receipt.getTransactionHash() != null) {
            System.out.println("transactionHash " + receipt.getTransactionHash());
        }
        if (receipt.getBlockNumber() != null) {
            System.out.println("blockNumber " + receipt.getBlockNumber());
        }
        if (!receipt.isStatusOK()) {
            throw new IllegalStateException("Transaction failed: " + receipt.getMessage());
        }
    }

    private void printValue(String value) {
        System.out.println(valueLabel + " " + value);
    }

    private String requireAddressFromEnv() {
        String address = System.getenv(addressEnvName);
        if (address == null || address.isBlank()) {
            throw new IllegalArgumentException(
                "Missing contract address. Pass <contractAddress> or set " + addressEnvName
            );
        }
        return address;
    }

    private String readValue(String raw) throws IOException {
        if (raw.startsWith("@")) {
            return normalizeValue(Files.readString(Path.of(raw.substring(1)), StandardCharsets.UTF_8));
        }

        try {
            Path path = Path.of(raw);
            if (Files.isRegularFile(path)) {
                return normalizeValue(Files.readString(path, StandardCharsets.UTF_8));
            }
        } catch (InvalidPathException ignored) {
            return normalizeValue(raw);
        }

        return normalizeValue(raw);
    }

    private String normalizeValue(String value) {
        String trimmed = value.trim();
        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            try {
                return GSON.toJson(JsonParser.parseString(trimmed));
            } catch (JsonSyntaxException ignored) {
                return trimmed;
            }
        }
        return trimmed;
    }

    private void requireArgs(String[] args, int expected) {
        if (args.length != expected) {
            usage();
            throw new IllegalArgumentException(
                "Expected " + expected + " arguments, got " + args.length
            );
        }
    }

    private void usage() {
        System.out.println(
            "Usage:\n"
                + "  blockNumber\n"
                + "  deploy\n"
                + "  register <contractAddress> <user> <" + valueArgumentName + ">\n"
                + "  register <user> <" + valueArgumentName + ">  # uses " + addressEnvName + "\n"
                + "  select <contractAddress> <user>\n"
                + "  query <user>  # uses " + addressEnvName + "\n"
                + "  history <contractAddress> <user> <blockNumber>\n"
                + "  history <user> <blockNumber>  # uses " + addressEnvName + "\n"
                + "\n"
                + "Payload arguments may be compact JSON, a file path, or @file."
        );
    }
}
