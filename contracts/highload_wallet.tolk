fun setActions(actions: Outlist): void asm "c5 POP";
fun builder.storeZeroes(mutate self, x: int): self asm "STZEROES";
fun acceptExternalMessage(): void asm "ACCEPT"; // for some reason not in stdlib


const internalTransferOp: int = 0xae42e5a4;
//unused consts should be deleted
const INVALID_SIGNATURE: int= 33;
const INVALID_SUBWALLET_ID: int = 34;
const INVALID_CREATED_AT: int = 35;
const ALREADY_EXECUTED: int = 36;
const INVALID_MESSAGE_TO_SEND: int= 37;
const INVALID_TIMEOUT: int= 38;

const KEY_SIZE: int = 13;
const SIGNATURE_SIZE: int = 512;
const PUBLIC_KEY_SIZE: int = 256;
const SUBWALLET_ID_SIZE: int = 32;
const TIMESTAMP_SIZE: int = 64;
const TIMEOUT_SIZE: int = 22; // 2^22 / 60 / 60 / 24 - up to ~48 days

const CELL_BIT_SIZE: int = 1023;
const BIT_NUMBER_SIZE: int = 10; // 2^10 = 1024
const MSG_QUERY_ID_SIZE: int = 64;
const MSG_OP_SIZE: int = 32;

type Outlist = cell;

struct (0xae42e5a4) InternalTransfer {
    queryId: uint64;
    actions: Cell<Outlist>;
}

struct ExternalInMsgBody {
   body: Cell<MsgInner>;
}   

struct MapValue<T> {
    zeroes: bits1023;
}

@inline
fun WalletStorage.newBitValue(mutate self, shift: uint13, bitNumber: uint10){
    var res = self.queries.get(shift);
    var value: builder? = null;
    if (res.isFound) {
        value = beginCell().storeSlice(res.loadValue());
    } else {
        value = beginCell().storeZeroes(bitNumber);
    }

    var valueSlice = value.beginParse();
    valueSlice.skipBits(bitNumber);
    assert (!valueSlice.preloadInt(1)) throw ALREADY_EXECUTED;

    
}



struct WalletStorage {
    publicKey: uint256;
    subwalletId: uint32;
    oldQueries: map<uint13, slice>;
    queries: map<uint13, slice>;
    lastCleanTime: int64;
    timeout: int22;
}

fun WalletStorage.save(self) {
    contract.setData(self.toCell());
}

fun WalletStorage.load() {
    return WalletStorage.fromCell(contract.getData());  
}

struct QueryId {
    shift: uint13;
    bitNumber: uint10;
}

struct MsgInner {
    subwalletId: uint32;
    messageToSend: cell?;
    sendMode: uint8;
    queryId: QueryId;
    createdAt: uint64;
    timeout: uint22;
}

type AllowedExternalMessageToWallet = ExternalInMsgBody;



fun onInternalMessage(in: InMessage) {
    val (bodyBits, bodyRefs) = in.body.remainingBitsAndRefsCount();
    if(!((bodyRefs == 1) & (bodyBits == MSG_OP_SIZE + MSG_QUERY_ID_SIZE))) {
        return();
    }   

    if(!(in.senderAddress == contract.getAddress())) {
        return();
    }

    val msg = InternalTransfer.fromSlice(in.body, { // needs to change Internal to Allowed
        throwIfOpcodeDoesNotMatch: 111, // has to be changed
    });
    
    val oldCode = contract.getCode();
    setActions(msg.actions);
    contract.setCodePostponed(oldCode);
    return();
}

fun onExternalMessage(inMsg: slice) {
    var signature = inMsg.getLastBits(512); // should be const above
    
    var storage = lazy WalletStorage.load();
    if (storage.lastCleanTime < (blockchain.now() - storage.timeout)) {
        (storage.oldQueries, storage.queries) = (storage.queries, createEmptyMap());
        if (storage.lastCleanTime < (blockchain.now() - (storage.timeout * 2))) {
            storage.oldQueries = createEmptyMap();
        }
        storage.lastCleanTime = blockchain.now();
    }
    
    var msg = lazy AllowedExternalMessageToWallet.fromSlice(inMsg);
    val msgInnerHash = msg.body.hash();

    assert(isSignatureValid(msgInnerHash, signature, storage.publicKey)) throw INVALID_SIGNATURE;

    var innerSlice = lazy MsgInner.fromCell(msg.body);

    assert(innerSlice.subwalletId == storage.subwalletId) throw INVALID_SUBWALLET_ID;
    assert(innerSlice.timeout == storage.timeout) throw INVALID_TIMEOUT;

    assert(innerSlice.createdAt > blockchain.now() - storage.timeout) throw INVALID_CREATED_AT;
    assert(innerSlice.createdAt <= blockchain.now()) throw INVALID_CREATED_AT;

    var resOld = storage.oldQueries.get(innerSlice.queryId.shift);
    if (resOld.isFound) {
        var value = resOld.loadValue();
        value.skipBits(innerSlice.queryId.bitNumber);
        assert(!value.preloadInt(1)) throw ALREADY_EXECUTED;
    }

    var res = storage.queries.get(innerSlice.queryId.shift);
    var newValue: builder? = null;
    if (res.isFound) {
        var value = res.loadValue();
        var head = value.loadBits(innerSlice.queryId.bitNumber);
        assert(!value.loadInt(1)) throw ALREADY_EXECUTED;

        // possible make to structs
        newValue = beginCell().storeSlice(head).storeBool(true).storeSlice(value);
    } else {
        newValue = beginCell().storeZeroes(innerSlice.queryId.bitNumber).storeBool(true).storeZeroes(CELL_BIT_SIZE - innerSlice.queryId.bitNumber - 1);
    }

    acceptExternalMessage();
    
    //storage.queries.set(innerSlice.queryId.shift, newValue.toSlice());


}