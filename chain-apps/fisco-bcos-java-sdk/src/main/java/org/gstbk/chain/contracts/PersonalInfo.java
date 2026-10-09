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
public class PersonalInfo extends Contract {
    public static final String[] BINARY_ARRAY = {"608060405234801561001057600080fd5b50600180546001600160a01b0319166110029081179091556040805180820182526006815265755f696e666f60d01b6020820152905163b0e89adb60e01b815263b0e89adb91610062916004016101a5565b6020604051808303816000875af1158015610081573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100a591906101fd565b506001546040805180820182526006815265755f696e666f60d01b6020820152905163f23f63c960e01b81526000926001600160a01b03169163f23f63c9916100f19190600401610227565b602060405180830381865afa15801561010e573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610132919061023a565b600080546001600160a01b0319166001600160a01b039290921691909117905550610263565b6000815180845260005b8181101561017e57602081850181015186830182015201610162565b81811115610190576000602083870101525b50601f01601f19169290920160200192915050565b6060815260006101b86060830184610158565b82810380602085015260048252633ab9b2b960e11b6020830152604081016040850152506004604082015263696e666f60e01b60608201526080810191505092915050565b60006020828403121561020f57600080fd5b81518060030b811461022057600080fd5b9392505050565b6020815260006102206020830184610158565b60006020828403121561024c57600080fd5b81516001600160a01b038116811461022057600080fd5b610a8480620002736000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633ffbd47f14610046578063776c00ee1461006c578063fcd7e3c11461008d575b600080fd5b61005961005436600461067c565b6100ae565b6040519081526020015b60405180910390f35b61007f61007a3660046106e0565b61025a565b604051610063929190610781565b6100a061009b3660046107a2565b610324565b6040516100639291906107d7565b600080600160606100be86610324565b909250905060018215151461017157600080546040516374a15a8b60e11b81526001600160a01b039091169063e942b51690610100908a908a906004016107f2565b6020604051808303816000875af115801561011f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906101439190610820565b90508060030b6001141561016557600093506101608743886103ab565b61016b565b60011993505b506101f2565b6000546040516374a15a8b60e11b81526001600160a01b039091169063e942b516906101a390899089906004016107f2565b6020604051808303816000875af11580156101c2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906101e69190610820565b506101f28643876103ab565b84604051610200919061084a565b604051809103902086604051610216919061084a565b604051908190038120858252907fe71002dee81d9ff68a8184c07ed89508062d232ea9979314fd048b99aca6f25e9060200160405180910390a35090949350505050565b600060606000606061026b86610324565b909250905060018215151461029257600019610287600061048e565b93509350505061031d565b6001855b80821015610307576000886102aa8361048e565b6040516020016102bb929190610866565b604051602081830303815290604052905060606102d782610324565b909650905085156102f35760009750955061031d945050505050565b6102fe6001846108b8565b92505050610296565b600119610314600061048e565b95509550505050505b9250929050565b6000805460405163349f642f60e11b8152606091839183916001600160a01b03169063693ec85e9061035a9088906004016108cf565b600060405180830381865afa158015610377573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f1916820160405261039f91908101906108e2565b90969095509350505050565b6000836103b78461048e565b6040516020016103c8929190610866565b60408051601f19818403018152908290526000546374a15a8b60e11b83529092506001600160a01b03169063e942b5169061040990849086906004016107f2565b6020604051808303816000875af1158015610428573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061044c9190610820565b507f0f24a19d28b7842785657ca099cfc4d70d9e1005a3ce66bf1432becc7c3b279d84838360405161048093929190610974565b60405180910390a150505050565b6060816104b25750506040805180820190915260018152600360fc1b602082015290565b8160005b81156104dc57806104c6816109b7565b91506104d59050600a836109d2565b91506104b6565b60008167ffffffffffffffff8111156104f7576104f76105b7565b6040519080825280601f01601f191660200182016040528015610521576020820181803683370190505b509050815b85156105ae576105376001826108b8565b90506000610546600a886109d2565b61055190600a6109f4565b61055b90886108b8565b610566906030610a13565b905060008160f81b90508084848151811061058357610583610a38565b60200101906001600160f81b031916908160001a9053506105a5600a896109d2565b97505050610526565b50949350505050565b634e487b7160e01b600052604160045260246000fd5b604051601f8201601f1916810167ffffffffffffffff811182821017156105f6576105f66105b7565b604052919050565b600067ffffffffffffffff821115610618576106186105b7565b50601f01601f191660200190565b600082601f83011261063757600080fd5b813561064a610645826105fe565b6105cd565b81815284602083860101111561065f57600080fd5b816020850160208301376000918101602001919091529392505050565b6000806040838503121561068f57600080fd5b823567ffffffffffffffff808211156106a757600080fd5b6106b386838701610626565b935060208501359150808211156106c957600080fd5b506106d685828601610626565b9150509250929050565b600080604083850312156106f357600080fd5b823567ffffffffffffffff81111561070a57600080fd5b61071685828601610626565b95602094909401359450505050565b60005b83811015610740578181015183820152602001610728565b8381111561074f576000848401525b50505050565b6000815180845261076d816020860160208601610725565b601f01601f19169290920160200192915050565b82815260406020820152600061079a6040830184610755565b949350505050565b6000602082840312156107b457600080fd5b813567ffffffffffffffff8111156107cb57600080fd5b61079a84828501610626565b821515815260406020820152600061079a6040830184610755565b6040815260006108056040830185610755565b82810360208401526108178185610755565b95945050505050565b60006020828403121561083257600080fd5b81518060030b811461084357600080fd5b9392505050565b6000825161085c818460208701610725565b9190910192915050565b60008351610878818460208801610725565b600160fe1b9083019081528351610896816001840160208801610725565b01600101949350505050565b634e487b7160e01b600052601160045260246000fd5b6000828210156108ca576108ca6108a2565b500390565b6020815260006108436020830184610755565b600080604083850312156108f557600080fd5b8251801515811461090557600080fd5b602084015190925067ffffffffffffffff81111561092257600080fd5b8301601f8101851361093357600080fd5b8051610941610645826105fe565b81815286602083850101111561095657600080fd5b610967826020830160208601610725565b8093505050509250929050565b6060815260006109876060830186610755565b82810360208401526109998186610755565b905082810360408401526109ad8185610755565b9695505050505050565b60006000198214156109cb576109cb6108a2565b5060010190565b6000826109ef57634e487b7160e01b600052601260045260246000fd5b500490565b6000816000190483118215151615610a0e57610a0e6108a2565b500290565b600060ff821660ff84168060ff03821115610a3057610a306108a2565b019392505050565b634e487b7160e01b600052603260045260246000fdfea2646970667358221220dfca30194bdb7156d76b5c38e685637ac26e2b5d1780a6b078ee94f5559183c264736f6c634300080b0033"};

    public static final String BINARY = org.fisco.bcos.sdk.v3.utils.StringUtils.joinAll("", BINARY_ARRAY);

    public static final String[] SM_BINARY_ARRAY = {"608060405234801561001057600080fd5b50600180546001600160a01b0319166110029081179091556040805180820182526006815265755f696e666f60d01b6020820152905163b0e89adb60e01b815263b0e89adb91610062916004016101a5565b6020604051808303816000875af1158015610081573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100a591906101fd565b506001546040805180820182526006815265755f696e666f60d01b6020820152905163f23f63c960e01b81526000926001600160a01b03169163f23f63c9916100f19190600401610227565b602060405180830381865afa15801561010e573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610132919061023a565b600080546001600160a01b0319166001600160a01b039290921691909117905550610263565b6000815180845260005b8181101561017e57602081850181015186830182015201610162565b81811115610190576000602083870101525b50601f01601f19169290920160200192915050565b6060815260006101b86060830184610158565b82810380602085015260048252633ab9b2b960e11b6020830152604081016040850152506004604082015263696e666f60e01b60608201526080810191505092915050565b60006020828403121561020f57600080fd5b81518060030b811461022057600080fd5b9392505050565b6020815260006102206020830184610158565b60006020828403121561024c57600080fd5b81516001600160a01b038116811461022057600080fd5b610a8480620002736000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633ffbd47f14610046578063776c00ee1461006c578063fcd7e3c11461008d575b600080fd5b61005961005436600461067c565b6100ae565b6040519081526020015b60405180910390f35b61007f61007a3660046106e0565b61025a565b604051610063929190610781565b6100a061009b3660046107a2565b610324565b6040516100639291906107d7565b600080600160606100be86610324565b909250905060018215151461017157600080546040516374a15a8b60e11b81526001600160a01b039091169063e942b51690610100908a908a906004016107f2565b6020604051808303816000875af115801561011f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906101439190610820565b90508060030b6001141561016557600093506101608743886103ab565b61016b565b60011993505b506101f2565b6000546040516374a15a8b60e11b81526001600160a01b039091169063e942b516906101a390899089906004016107f2565b6020604051808303816000875af11580156101c2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906101e69190610820565b506101f28643876103ab565b84604051610200919061084a565b604051809103902086604051610216919061084a565b604051908190038120858252907fe71002dee81d9ff68a8184c07ed89508062d232ea9979314fd048b99aca6f25e9060200160405180910390a35090949350505050565b600060606000606061026b86610324565b909250905060018215151461029257600019610287600061048e565b93509350505061031d565b6001855b80821015610307576000886102aa8361048e565b6040516020016102bb929190610866565b604051602081830303815290604052905060606102d782610324565b909650905085156102f35760009750955061031d945050505050565b6102fe6001846108b8565b92505050610296565b600119610314600061048e565b95509550505050505b9250929050565b6000805460405163349f642f60e11b8152606091839183916001600160a01b03169063693ec85e9061035a9088906004016108cf565b600060405180830381865afa158015610377573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f1916820160405261039f91908101906108e2565b90969095509350505050565b6000836103b78461048e565b6040516020016103c8929190610866565b60408051601f19818403018152908290526000546374a15a8b60e11b83529092506001600160a01b03169063e942b5169061040990849086906004016107f2565b6020604051808303816000875af1158015610428573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061044c9190610820565b507f0f24a19d28b7842785657ca099cfc4d70d9e1005a3ce66bf1432becc7c3b279d84838360405161048093929190610974565b60405180910390a150505050565b6060816104b25750506040805180820190915260018152600360fc1b602082015290565b8160005b81156104dc57806104c6816109b7565b91506104d59050600a836109d2565b91506104b6565b60008167ffffffffffffffff8111156104f7576104f76105b7565b6040519080825280601f01601f191660200182016040528015610521576020820181803683370190505b509050815b85156105ae576105376001826108b8565b90506000610546600a886109d2565b61055190600a6109f4565b61055b90886108b8565b610566906030610a13565b905060008160f81b90508084848151811061058357610583610a38565b60200101906001600160f81b031916908160001a9053506105a5600a896109d2565b97505050610526565b50949350505050565b634e487b7160e01b600052604160045260246000fd5b604051601f8201601f1916810167ffffffffffffffff811182821017156105f6576105f66105b7565b604052919050565b600067ffffffffffffffff821115610618576106186105b7565b50601f01601f191660200190565b600082601f83011261063757600080fd5b813561064a610645826105fe565b6105cd565b81815284602083860101111561065f57600080fd5b816020850160208301376000918101602001919091529392505050565b6000806040838503121561068f57600080fd5b823567ffffffffffffffff808211156106a757600080fd5b6106b386838701610626565b935060208501359150808211156106c957600080fd5b506106d685828601610626565b9150509250929050565b600080604083850312156106f357600080fd5b823567ffffffffffffffff81111561070a57600080fd5b61071685828601610626565b95602094909401359450505050565b60005b83811015610740578181015183820152602001610728565b8381111561074f576000848401525b50505050565b6000815180845261076d816020860160208601610725565b601f01601f19169290920160200192915050565b82815260406020820152600061079a6040830184610755565b949350505050565b6000602082840312156107b457600080fd5b813567ffffffffffffffff8111156107cb57600080fd5b61079a84828501610626565b821515815260406020820152600061079a6040830184610755565b6040815260006108056040830185610755565b82810360208401526108178185610755565b95945050505050565b60006020828403121561083257600080fd5b81518060030b811461084357600080fd5b9392505050565b6000825161085c818460208701610725565b9190910192915050565b60008351610878818460208801610725565b600160fe1b9083019081528351610896816001840160208801610725565b01600101949350505050565b634e487b7160e01b600052601160045260246000fd5b6000828210156108ca576108ca6108a2565b500390565b6020815260006108436020830184610755565b600080604083850312156108f557600080fd5b8251801515811461090557600080fd5b602084015190925067ffffffffffffffff81111561092257600080fd5b8301601f8101851361093357600080fd5b8051610941610645826105fe565b81815286602083850101111561095657600080fd5b610967826020830160208601610725565b8093505050509250929050565b6060815260006109876060830186610755565b82810360208401526109998186610755565b905082810360408401526109ad8185610755565b9695505050505050565b60006000198214156109cb576109cb6108a2565b5060010190565b6000826109ef57634e487b7160e01b600052601260045260246000fd5b500490565b6000816000190483118215151615610a0e57610a0e6108a2565b500290565b600060ff821660ff84168060ff03821115610a3057610a306108a2565b019392505050565b634e487b7160e01b600052603260045260246000fdfea2646970667358221220dfca30194bdb7156d76b5c38e685637ac26e2b5d1780a6b078ee94f5559183c264736f6c634300080b0033"};

    public static final String SM_BINARY = org.fisco.bcos.sdk.v3.utils.StringUtils.joinAll("", SM_BINARY_ARRAY);

    public static final String[] ABI_ARRAY = {"[{\"inputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"int256\",\"name\":\"ret\",\"type\":\"int256\"},{\"indexed\":true,\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"indexed\":true,\"internalType\":\"string\",\"name\":\"info\",\"type\":\"string\"}],\"name\":\"RegisterEvent\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"info\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"}],\"name\":\"UpdateEvent\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"info\",\"type\":\"string\"}],\"name\":\"register\",\"outputs\":[{\"internalType\":\"int256\",\"name\":\"\",\"type\":\"int256\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"}],\"name\":\"select\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"},{\"internalType\":\"string\",\"name\":\"\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"user\",\"type\":\"string\"},{\"internalType\":\"uint256\",\"name\":\"block_number\",\"type\":\"uint256\"}],\"name\":\"selectWithBlockNumber\",\"outputs\":[{\"internalType\":\"int256\",\"name\":\"\",\"type\":\"int256\"},{\"internalType\":\"string\",\"name\":\"\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"};

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

    protected PersonalInfo(String contractAddress, Client client, CryptoKeyPair credential) {
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
            typedResponse.info = (byte[]) eventValues.getIndexedValues().get(1).getValue();
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
            typedResponse.info = (String) eventValues.getNonIndexedValues().get(1).getValue();
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

    public TransactionReceipt register(String user, String info) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(info)), 
                Collections.<TypeReference<?>>emptyList(), 0);
        return executeTransaction(function);
    }

    public Function getMethodRegisterRawFunction(String user, String info) throws
            ContractException {
        final Function function = new Function(FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(info)), 
                Arrays.<TypeReference<?>>asList(new TypeReference<Int256>() {}));
        return function;
    }

    public String getSignedTransactionForRegister(String user, String info) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(info)), 
                Collections.<TypeReference<?>>emptyList(), 0);
        return createSignedTransaction(function);
    }

    public String register(String user, String info, TransactionCallback callback) {
        final Function function = new Function(
                FUNC_REGISTER, 
                Arrays.<Type>asList(new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(user), 
                new org.fisco.bcos.sdk.v3.codec.datatypes.Utf8String(info)), 
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

    public static PersonalInfo load(String contractAddress, Client client,
            CryptoKeyPair credential) {
        return new PersonalInfo(contractAddress, client, credential);
    }

    public static PersonalInfo deploy(Client client, CryptoKeyPair credential) throws
            ContractException {
        return deploy(PersonalInfo.class, client, credential, getBinary(client.getCryptoSuite()), getABI(), null, null);
    }

    public static class RegisterEventEventResponse {
        public TransactionReceipt.Logs log;

        public byte[] user;

        public byte[] info;

        public BigInteger ret;
    }

    public static class UpdateEventEventResponse {
        public TransactionReceipt.Logs log;

        public String user;

        public String info;

        public String key;
    }
}
