package org.gstbk.chain.contracts;

import java.math.BigInteger;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import org.fisco.bcos.sdk.v3.client.Client;
import org.fisco.bcos.sdk.v3.codec.datatypes.Bool;
import org.fisco.bcos.sdk.v3.codec.datatypes.Event;
import org.fisco.bcos.sdk.v3.codec.datatypes.Function;
import org.fisco.bcos.sdk.v3.codec.datatypes.Type;
import org.fisco.bcos.sdk.v3.codec.datatypes.TypeReference;
import org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String;
import org.fisco.bcos.sdk.v3.codec.datatypes.generated.Int256;
import org.fisco.bcos.sdk.v3.codec.datatypes.generated.tuples.generated.Tuple1;
import org.fisco.bcos.sdk.v3.codec.datatypes.generated.tuples.generated.Tuple2;
import org.fisco.bcos.sdk.v3.contract.Contract;
import org.fisco.bcos.sdk.v3.crypto.CryptoSuite;
import org.fisco.bcos.sdk.v3.crypto.keypair.CryptoKeyPair;
import org.fisco.bcos.sdk.v3.eventsub.EventSubCallback;
import org.fisco.bcos.sdk.v3.model.CryptoType;
import org.fisco.bcos.sdk.v3.model.TransactionReceipt;
import org.fisco.bcos.sdk.v3.model.callback.TransactionCallback;
import org.fisco.bcos.sdk.v3.transaction.manager.transactionv1.ProxySignTransactionManager;
import org.fisco.bcos.sdk.v3.transaction.model.exception.ContractException;

@SuppressWarnings("unchecked")
public class Signature extends Contract {
    public static final String[] BINARY_ARRAY = {"608060405234801561001057600080fd5b50600180546001600160a01b031916611002908117909155604080518082018252600c81526b755f7369676e61747572657360a01b6020820152905163b0e89adb60e01b815263b0e89adb91610068916004016101b1565b6020604051808303816000875af1158015610087573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100ab919061020f565b50600154604080518082018252600c81526b755f7369676e61747572657360a01b6020820152905163f23f63c960e01b81526000926001600160a01b03169163f23f63c9916100fd9190600401610239565b602060405180830381865afa15801561011a573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061013e919061024c565b600080546001600160a01b0319166001600160a01b039290921691909117905550610275565b6000815180845260005b8181101561018a5760208185018101518683018201520161016e565b8181111561019c576000602083870101525b50601f01601f19169290920160200192915050565b6060815260006101c46060830184610164565b82810380602085015260048252633ab9b2b960e11b602083015260408101604085015250600a6040820152697369676e61747572657360b01b60608201526080810191505092915050565b60006020828403121561022157600080fd5b81518060030b811461023257600080fd5b9392505050565b6020815260006102326020830184610164565b60006020828403121561025e57600080fd5b81516001600160a01b038116811461023257600080fd5b610a09806102846000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633ffbd47f14610046578063776c00ee1461006c578063fcd7e3c11461008d575b600080fd5b610059610054366004610601565b6100ae565b6040519081526020015b60405180910390f35b61007f61007a366004610665565b6101df565b604051610063929190610706565b6100a061009b366004610727565b6102a9565b60405161006392919061075c565b600080600160606100be866102a9565b909250905060018215151461017157600080546040516374a15a8b60e11b81526001600160a01b039091169063e942b51690610100908a908a90600401610777565b6020604051808303816000875af115801561011f573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061014391906107a5565b90508060030b600114156101655760009350610160874388610330565b61016b565b60011993505b50610177565b60001992505b8460405161018591906107cf565b60405180910390208660405161019b91906107cf565b604051908190038120858252907fe71002dee81d9ff68a8184c07ed89508062d232ea9979314fd048b99aca6f25e9060200160405180910390a35090949350505050565b60006060600060606101f0866102a9565b90925090506001821515146102175760001961020c6000610413565b9350935050506102a2565b6001855b8082101561028c5760008861022f83610413565b6040516020016102409291906107eb565b6040516020818303038152906040529050606061025c826102a9565b90965090508515610278576000975095506102a2945050505050565b61028360018461083d565b9250505061021b565b6001196102996000610413565b95509550505050505b9250929050565b6000805460405163349f642f60e11b8152606091839183916001600160a01b03169063693ec85e906102df908890600401610854565b600060405180830381865afa1580156102fc573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f191682016040526103249190810190610867565b90969095509350505050565b60008361033c84610413565b60405160200161034d9291906107eb565b60408051601f19818403018152908290526000546374a15a8b60e11b83529092506001600160a01b03169063e942b5169061038e9084908690600401610777565b6020604051808303816000875af11580156103ad573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103d191906107a5565b507f0f24a19d28b7842785657ca099cfc4d70d9e1005a3ce66bf1432becc7c3b279d848383604051610405939291906108f9565b60405180910390a150505050565b6060816104375750506040805180820190915260018152600360fc1b602082015290565b8160005b8115610461578061044b8161093c565b915061045a9050600a83610957565b915061043b565b60008167ffffffffffffffff81111561047c5761047c61053c565b6040519080825280601f01601f1916602001820160405280156104a6576020820181803683370190505b509050815b8515610533576104bc60018261083d565b905060006104cb600a88610957565b6104d690600a610979565b6104e0908861083d565b6104eb906030610998565b905060008160f81b905080848481518110610508576105086109bd565b60200101906001600160f81b031916908160001a90535061052a600a89610957565b975050506104ab565b50949350505050565b634e487b7160e01b600052604160045260246000fd5b604051601f8201601f1916810167ffffffffffffffff8111828210171561057b5761057b61053c565b604052919050565b600067ffffffffffffffff82111561059d5761059d61053c565b50601f01601f191660200190565b600082601f8301126105bc57600080fd5b81356105cf6105ca82610583565b610552565b8181528460208386010111156105e457600080fd5b816020850160208301376000918101602001919091529392505050565b6000806040838503121561061457600080fd5b823567ffffffffffffffff8082111561062c57600080fd5b610638868387016105ab565b9350602085013591508082111561064e57600080fd5b5061065b858286016105ab565b9150509250929050565b6000806040838503121561067857600080fd5b823567ffffffffffffffff81111561068f57600080fd5b61069b858286016105ab565b95602094909401359450505050565b60005b838110156106c55781810151838201526020016106ad565b838111156106d4576000848401525b50505050565b600081518084526106f28160208601602086016106aa565b601f01601f19169290920160200192915050565b82815260406020820152600061071f60408301846106da565b949350505050565b60006020828403121561073957600080fd5b813567ffffffffffffffff81111561075057600080fd5b61071f848285016105ab565b821515815260406020820152600061071f60408301846106da565b60408152600061078a60408301856106da565b828103602084015261079c81856106da565b95945050505050565b6000602082840312156107b757600080fd5b81518060030b81146107c857600080fd5b9392505050565b600082516107e18184602087016106aa565b9190910192915050565b600083516107fd8184602088016106aa565b600160fe1b908301908152835161081b8160018401602088016106aa565b01600101949350505050565b634e487b7160e01b600052601160045260246000fd5b60008282101561084f5761084f610827565b500390565b6020815260006107c860208301846106da565b6000806040838503121561087a57600080fd5b8251801515811461088a57600080fd5b602084015190925067ffffffffffffffff8111156108a757600080fd5b8301601f810185136108b857600080fd5b80516108c66105ca82610583565b8181528660208385010111156108db57600080fd5b6108ec8260208301602086016106aa565b8093505050509250929050565b60608152600061090c60608301866106da565b828103602084015261091e81866106da565b9050828103604084015261093281856106da565b9695505050505050565b600060001982141561095057610950610827565b5060010190565b60008261097457634e487b7160e01b600052601260045260246000fd5b500490565b600081600019048311821515161561099357610993610827565b500290565b600060ff821660ff84168060ff038211156109b5576109b5610827565b019392505050565b634e487b7160e01b600052603260045260246000fdfea2646970667358221220465b6f67b6052008b15566f1e3522bdad1c29493c3278c7707c522b1aa50aa2164736f6c634300080b0033"};

    public static final String BINARY = org.fisco.bcos.sdk.v3.utils.StringUtils.joinAll("", BINARY_ARRAY);

    public static final String[] SM_BINARY_ARRAY = {"608060405234801561001057600080fd5b50600180546001600160a01b031916611002908117909155604080518082018252600c81526b755f7369676e61747572657360a01b6020820152905163b0e89adb60e01b815263b0e89adb91610068916004016101b1565b6020604051808303816000875af1158015610087573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100ab919061020f565b50600154604080518082018252600c81526b755f7369676e61747572657360a01b6020820152905163f23f63c960e01b81526000926001600160a01b03169163f23f63c9916100fd9190600401610239565b602060405180830381865afa15801561011a573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061013e919061024c565b600080546001600160a01b0319166001600160a01b039290921691909117905550610275565b6000815180845260005b8181101561018a5760208185018101518683018201520161016e565b8181111561019c576000602083870101525b50601f01601f19169290920160200192915050565b6060815260006101c46060830184610164565b82810380602085015260048252633ab9b2b960e11b602083015260408101604085015250600a6040820152697369676e61747572657360b01b60608201526080810191505092915050565b60006020828403121561022157600080fd5b81518060030b811461023257600080fd5b9392505050565b6020815260006102326020830184610164565b60006020828403121561025e57600080fd5b81516001600160a01b038116811461023257600080fd5b610a09806102846000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633ffbd47f14610046578063776c00ee1461006c578063fcd7e3c11461008d575b600080fd5b610059610054366004610601565b6100ae565b6040519081526020015b60405180910390f35b61007f61007a366004610665565b6101df565b604051610063929190610706565b6100a061009b366004610727565b6102a9565b60405161006392919061075c565b600080600160606100be866102a9565b909250905060018215151461017157600080546040516374a15a8b60e11b81526001600160a01b039091169063e942b51690610100908a908a90600401610777565b6020604051808303816000875af115801561011f573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061014391906107a5565b90508060030b600114156101655760009350610160874388610330565b61016b565b60011993505b50610177565b60001992505b8460405161018591906107cf565b60405180910390208660405161019b91906107cf565b604051908190038120858252907fe71002dee81d9ff68a8184c07ed89508062d232ea9979314fd048b99aca6f25e9060200160405180910390a35090949350505050565b60006060600060606101f0866102a9565b90925090506001821515146102175760001961020c6000610413565b9350935050506102a2565b6001855b8082101561028c5760008861022f83610413565b6040516020016102409291906107eb565b6040516020818303038152906040529050606061025c826102a9565b90965090508515610278576000975095506102a2945050505050565b61028360018461083d565b9250505061021b565b6001196102996000610413565b95509550505050505b9250929050565b6000805460405163349f642f60e11b8152606091839183916001600160a01b03169063693ec85e906102df908890600401610854565b600060405180830381865afa1580156102fc573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f191682016040526103249190810190610867565b90969095509350505050565b60008361033c84610413565b60405160200161034d9291906107eb565b60408051601f19818403018152908290526000546374a15a8b60e11b83529092506001600160a01b03169063e942b5169061038e9084908690600401610777565b6020604051808303816000875af11580156103ad573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103d191906107a5565b507f0f24a19d28b7842785657ca099cfc4d70d9e1005a3ce66bf1432becc7c3b279d848383604051610405939291906108f9565b60405180910390a150505050565b6060816104375750506040805180820190915260018152600360fc1b602082015290565b8160005b8115610461578061044b8161093c565b915061045a9050600a83610957565b915061043b565b60008167ffffffffffffffff81111561047c5761047c61053c565b6040519080825280601f01601f1916602001820160405280156104a6576020820181803683370190505b509050815b8515610533576104bc60018261083d565b905060006104cb600a88610957565b6104d690600a610979565b6104e0908861083d565b6104eb906030610998565b905060008160f81b905080848481518110610508576105086109bd565b60200101906001600160f81b031916908160001a90535061052a600a89610957565b975050506104ab565b50949350505050565b634e487b7160e01b600052604160045260246000fd5b604051601f8201601f1916810167ffffffffffffffff8111828210171561057b5761057b61053c565b604052919050565b600067ffffffffffffffff82111561059d5761059d61053c565b50601f01601f191660200190565b600082601f8301126105bc57600080fd5b81356105cf6105ca82610583565b610552565b8181528460208386010111156105e457600080fd5b816020850160208301376000918101602001919091529392505050565b6000806040838503121561061457600080fd5b823567ffffffffffffffff8082111561062c57600080fd5b610638868387016105ab565b9350602085013591508082111561064e57600080fd5b5061065b858286016105ab565b9150509250929050565b6000806040838503121561067857600080fd5b823567ffffffffffffffff81111561068f57600080fd5b61069b858286016105ab565b95602094909401359450505050565b60005b838110156106c55781810151838201526020016106ad565b838111156106d4576000848401525b50505050565b600081518084526106f28160208601602086016106aa565b601f01601f19169290920160200192915050565b82815260406020820152600061071f60408301846106da565b949350505050565b60006020828403121561073957600080fd5b813567ffffffffffffffff81111561075057600080fd5b61071f848285016105ab565b821515815260406020820152600061071f60408301846106da565b60408152600061078a60408301856106da565b828103602084015261079c81856106da565b95945050505050565b6000602082840312156107b757600080fd5b81518060030b81146107c857600080fd5b9392505050565b600082516107e18184602087016106aa565b9190910192915050565b600083516107fd8184602088016106aa565b600160fe1b908301908152835161081b8160018401602088016106aa565b01600101949350505050565b634e487b7160e01b600052601160045260246000fd5b60008282101561084f5761084f610827565b500390565b6020815260006107c860208301846106da565b6000806040838503121561087a57600080fd5b8251801515811461088a57600080fd5b602084015190925067ffffffffffffffff8111156108a757600080fd5b8301601f810185136108b857600080fd5b80516108c66105ca82610583565b8181528660208385010111156108db57600080fd5b6108ec8260208301602086016106aa565b8093505050509250929050565b60608152600061090c60608301866106da565b828103602084015261091e81866106da565b9050828103604084015261093281856106da565b9695505050505050565b600060001982141561095057610950610827565b5060010190565b60008261097457634e487b7160e01b600052601260045260246000fd5b500490565b600081600019048311821515161561099357610993610827565b500290565b600060ff821660ff84168060ff038211156109b5576109b5610827565b019392505050565b634e487b7160e01b600052603260045260246000fdfea2646970667358221220465b6f67b6052008b15566f1e3522bdad1c29493c3278c7707c522b1aa50aa2164736f6c634300080b0033"};

    public static final String SM_BINARY = org.fisco.bcos.sdk.v3.utils.StringUtils.joinAll("", SM_BINARY_ARRAY);

    public static final String[] ABI_ARRAY = {"[{\"inputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"int256\",\"name\":\"ret\",\"type\":\"int256\"},{\"indexed\":true,\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"indexed\":true,\"internalType\":\"string\",\"name\":\"signatures\",\"type\":\"string\"}],\"name\":\"RegisterEvent\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"signatures\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"}],\"name\":\"UpdateEvent\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"signatures\",\"type\":\"string\"}],\"name\":\"register\",\"outputs\":[{\"internalType\":\"int256\",\"name\":\"\",\"type\":\"int256\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"}],\"name\":\"select\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"},{\"internalType\":\"string\",\"name\":\"\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"internalType\":\"uint256\",\"name\":\"block_number\",\"type\":\"uint256\"}],\"name\":\"selectWithBlockNumber\",\"outputs\":[{\"internalType\":\"int256\",\"name\":\"\",\"type\":\"int256\"},{\"internalType\":\"string\",\"name\":\"\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"};

    public static final String ABI = org.fisco.bcos.sdk.v3.utils.StringUtils.joinAll("", ABI_ARRAY);

    public static final String FUNC_REGISTER = "register";

    public static final String FUNC_SELECT = "select";

    public static final String FUNC_SELECTWITHBLOCKNUMBER = "selectWithBlockNumber";

    public static final Event REGISTEREVENT_EVENT = new Event("RegisterEvent", 
            Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}, new TypeReference<Utf8String>(true) {}, new TypeReference<Utf8String>(true) {}));
    ;

    public static final Event UPDATEEVENT_EVENT = new Event("UpdateEvent", 
            Arrays.<TypeReference<?>>asList(new TypeReference<Utf8String>() {}, new TypeReference<Utf8String>() {}, new TypeReference<Utf8String>() {}));
    ;

    protected Signature(String contractAddress, Client client, CryptoKeyPair credential) {
        super(getBinary(client.getCryptoSuite()), contractAddress, client, credential);
        this.transactionManager = new ProxySignTransactionManager(client);
    }

    public static String getBinary(CryptoSuite cryptoSuite) {
        return (cryptoSuite.getCryptoTypeConfig() == CryptoType.ECDSA_TYPE ? BINARY : SM_BINARY);
    }

    public static String getABI() {
        return ABI;
    }

    public List<RegisterEventEventResponse> getRegisterEventEvents(
            TransactionReceipt transactionReceipt) {
        List<Contract.EventValuesWithLog> valueList = extractEventParametersWithLog(REGISTEREVENT_EVENT, transactionReceipt);
        ArrayList<RegisterEventEventResponse> responses = new ArrayList<RegisterEventEventResponse>(valueList.size());
        for (Contract.EventValuesWithLog eventValues : valueList) {
            RegisterEventEventResponse typedResponse = new RegisterEventEventResponse();
            typedResponse.log = eventValues.getLog();
            typedResponse.user = (byte[]) eventValues.getIndexedValues().get(0).getValue();
            typedResponse.signatures = (byte[]) eventValues.getIndexedValues().get(1).getValue();
            typedResponse.ret = (BigInteger) eventValues.getNonIndexedValues().get(0).getValue();
            responses.add(typedResponse);
        }
        return responses;
    }

    public void subscribeRegisterEventEvent(BigInteger fromBlock, BigInteger toBlock,
            List<String> otherTopics, EventSubCallback callback) {
        String topic0 = eventEncoder.encode(REGISTEREVENT_EVENT);
        subscribeEvent(topic0,otherTopics,fromBlock,toBlock,callback);
    }

    public void subscribeRegisterEventEvent(EventSubCallback callback) {
        String topic0 = eventEncoder.encode(REGISTEREVENT_EVENT);
        subscribeEvent(topic0,callback);
    }

    public List<UpdateEventEventResponse> getUpdateEventEvents(
            TransactionReceipt transactionReceipt) {
        List<Contract.EventValuesWithLog> valueList = extractEventParametersWithLog(UPDATEEVENT_EVENT, transactionReceipt);
        ArrayList<UpdateEventEventResponse> responses = new ArrayList<UpdateEventEventResponse>(valueList.size());
        for (Contract.EventValuesWithLog eventValues : valueList) {
            UpdateEventEventResponse typedResponse = new UpdateEventEventResponse();
            typedResponse.log = eventValues.getLog();
            typedResponse.user = (String) eventValues.getNonIndexedValues().get(0).getValue();
            typedResponse.signatures = (String) eventValues.getNonIndexedValues().get(1).getValue();
            typedResponse.key = (String) eventValues.getNonIndexedValues().get(2).getValue();
            responses.add(typedResponse);
        }
        return responses;
    }

    public void subscribeUpdateEventEvent(BigInteger fromBlock, BigInteger toBlock,
            List<String> otherTopics, EventSubCallback callback) {
        String topic0 = eventEncoder.encode(UPDATEEVENT_EVENT);
        subscribeEvent(topic0,otherTopics,fromBlock,toBlock,callback);
    }

    public void subscribeUpdateEventEvent(EventSubCallback callback) {
        String topic0 = eventEncoder.encode(UPDATEEVENT_EVENT);
        subscribeEvent(topic0,callback);
    }

    public TransactionReceipt register(String user, String signatures) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(signatures)), 
                Collections.<TypeReference<?>>emptyList(), 0);
        return executeTransaction(function);
    }

    public Function getMethodRegisterRawFunction(String user, String signatures) throws
            ContractException {
        final Function function = new Function(FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(signatures)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}));
        return function;
    }

    public String getSignedTransactionForRegister(String user, String signatures) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(signatures)), 
                Collections.<TypeReference<?>>emptyList(), 0);
        return createSignedTransaction(function);
    }

    public String register(String user, String signatures, TransactionCallback callback) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(signatures)), 
                Collections.<TypeReference<?>>emptyList(), 0);
        return asyncExecuteTransaction(function, callback);
    }

    public Tuple2<String, String> getRegisterInput(TransactionReceipt transactionReceipt) {
        String data = transactionReceipt.getInput().substring(10);
        final Function function = new Function(FUNC_REGISTER, 
                Arrays.<Type>asList(), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Utf8String>() {}, new TypeReference<Utf8String>() {}));
        List<Type> results = this.functionReturnDecoder.decode(data, function.getOutputParameters());
        return new Tuple2<String, String>(

                (String) results.get(0).getValue(), 
                (String) results.get(1).getValue()
                );
    }

    public Tuple1<BigInteger> getRegisterOutput(TransactionReceipt transactionReceipt) {
        String data = transactionReceipt.getOutput();
        final Function function = new Function(FUNC_REGISTER, 
                Arrays.<Type>asList(), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}));
        List<Type> results = this.functionReturnDecoder.decode(data, function.getOutputParameters());
        return new Tuple1<BigInteger>(

                (BigInteger) results.get(0).getValue()
                );
    }

    public Tuple2<Boolean, String> select(String user) throws ContractException {
        final Function function = new Function(FUNC_SELECT, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Bool>() {}, new TypeReference<Utf8String>() {}));
        List<Type> results = executeCallWithMultipleValueReturn(function);
        return new Tuple2<Boolean, String>(
                (Boolean) results.get(0).getValue(), 
                (String) results.get(1).getValue());
    }

    public Function getMethodSelectRawFunction(String user) throws ContractException {
        final Function function = new Function(FUNC_SELECT, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Bool>() {}, new TypeReference<Utf8String>() {}));
        return function;
    }

    public Tuple2<BigInteger, String> selectWithBlockNumber(String user, BigInteger block_number)
            throws ContractException {
        final Function function = new Function(FUNC_SELECTWITHBLOCKNUMBER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.generated.Uint256(block_number)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}, new TypeReference<Utf8String>() {}));
        List<Type> results = executeCallWithMultipleValueReturn(function);
        return new Tuple2<BigInteger, String>(
                (BigInteger) results.get(0).getValue(), 
                (String) results.get(1).getValue());
    }

    public Function getMethodSelectWithBlockNumberRawFunction(String user, BigInteger block_number)
            throws ContractException {
        final Function function = new Function(FUNC_SELECTWITHBLOCKNUMBER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.generated.Uint256(block_number)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}, new TypeReference<Utf8String>() {}));
        return function;
    }

    public static Signature load(String contractAddress, Client client, CryptoKeyPair credential) {
        return new Signature(contractAddress, client, credential);
    }

    public static Signature deploy(Client client, CryptoKeyPair credential) throws
            ContractException {
        return deploy(Signature.class, client, credential, getBinary(client.getCryptoSuite()), getABI(), null, null);
    }

    public static class RegisterEventEventResponse {
        public TransactionReceipt.Logs log;

        public byte[] user;

        public byte[] signatures;

        public BigInteger ret;
    }

    public static class UpdateEventEventResponse {
        public TransactionReceipt.Logs log;

        public String user;

        public String signatures;

        public String key;
    }
}
