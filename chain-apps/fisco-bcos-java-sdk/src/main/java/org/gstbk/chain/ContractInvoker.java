package org.gstbk.chain;

import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.math.BigInteger;
import org.fisco.bcos.sdk.v3.client.Client;
import org.fisco.bcos.sdk.v3.crypto.keypair.CryptoKeyPair;
import org.fisco.bcos.sdk.v3.model.TransactionReceipt;

final class ContractInvoker {
    private static final String CONTRACT_PACKAGE = "org.gstbk.chain.contracts";

    private ContractInvoker() {}

    static Object deploy(String simpleName, ChainContext context) throws Exception {
        Class<?> contractClass = contractClass(simpleName);
        Method deploy = contractClass.getMethod("deploy", Client.class, CryptoKeyPair.class);
        return deploy.invoke(null, context.client(), context.keyPair());
    }

    static Object load(String simpleName, String address, ChainContext context) throws Exception {
        Class<?> contractClass = contractClass(simpleName);
        Method load = contractClass.getMethod("load", String.class, Client.class, CryptoKeyPair.class);
        return load.invoke(null, address, context.client(), context.keyPair());
    }

    static RegisterResult register(Object contract, String user, String value) throws Exception {
        TransactionReceipt receipt = (TransactionReceipt) contract.getClass()
            .getMethod("register", String.class, String.class)
            .invoke(contract, user, value);

        BigInteger retCode = null;
        if (receipt != null && receipt.isStatusOK()) {
            Object tuple = contract.getClass()
                .getMethod("getRegisterOutput", TransactionReceipt.class)
                .invoke(contract, receipt);
            retCode = (BigInteger) value(tuple, 1);
        }

        return new RegisterResult(receipt, retCode);
    }

    static SelectResult select(Object contract, String user) throws Exception {
        Object tuple = contract.getClass().getMethod("select", String.class).invoke(contract, user);
        return new SelectResult((Boolean) value(tuple, 1), String.valueOf(value(tuple, 2)));
    }

    static HistoryResult selectWithBlockNumber(Object contract, String user, BigInteger blockNumber)
            throws Exception {
        Object tuple = contract.getClass()
            .getMethod("selectWithBlockNumber", String.class, BigInteger.class)
            .invoke(contract, user, blockNumber);
        return new HistoryResult((BigInteger) value(tuple, 1), String.valueOf(value(tuple, 2)));
    }

    static String contractAddress(Object contract) {
        try {
            Method method = contract.getClass().getMethod("getContractAddress");
            Object address = method.invoke(contract);
            return String.valueOf(address);
        } catch (ReflectiveOperationException ignored) {
            return "<address-unavailable>";
        }
    }

    private static Class<?> contractClass(String simpleName) throws ClassNotFoundException {
        Class<?> clazz = Class.forName(CONTRACT_PACKAGE + "." + simpleName);
        if (Modifier.isAbstract(clazz.getModifiers())) {
            throw new IllegalStateException("Generated contract wrapper is abstract: " + clazz.getName());
        }
        return clazz;
    }

    private static Object value(Object tuple, int index) throws Exception {
        return tuple.getClass().getMethod("getValue" + index).invoke(tuple);
    }

    static final class RegisterResult {
        private final TransactionReceipt receipt;
        private final BigInteger retCode;

        RegisterResult(TransactionReceipt receipt, BigInteger retCode) {
            this.receipt = receipt;
            this.retCode = retCode;
        }

        TransactionReceipt receipt() {
            return receipt;
        }

        BigInteger retCode() {
            return retCode;
        }
    }

    static final class SelectResult {
        private final boolean exists;
        private final String value;

        SelectResult(boolean exists, String value) {
            this.exists = exists;
            this.value = value;
        }

        boolean exists() {
            return exists;
        }

        String value() {
            return value;
        }
    }

    static final class HistoryResult {
        private final BigInteger retCode;
        private final String value;

        HistoryResult(BigInteger retCode, String value) {
            this.retCode = retCode;
            this.value = value;
        }

        BigInteger retCode() {
            return retCode;
        }

        String value() {
            return value;
        }
    }
}
