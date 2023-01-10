import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Option "mo:base/Option";
import Prim "mo:prim";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Nat32 "mo:base/Nat32";
import JSON "../helpers/JSON";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Transaction "../models/Transaction";
import Hex "mo:encoding/Hex";
import SHA256 "mo:crypto/SHA/SHA256";
import DatabaseService "../services/DatabaseService"

module {

    private type JSON = JSON.JSON;
    private type Transaction = Transaction.Transaction;

    public func natToFloat(value:Nat): Float {
        //var nat64 = Nat64.fromNat(value);
        //var int64 = Int64.fromNat64(nat64);
        return Float.fromInt(value)
    };

    public func floatToNat(value:Float): Nat {
        let int = Float.toInt(value);
        return textToNat(Int.toText(int))
    };

    public func includesText(string: Text, term: Text): Bool {
        let stringArray = Iter.toArray<Char>(toLowerCase(string).chars());
        let termArray = Iter.toArray<Char>(toLowerCase(term).chars());

        var i = 0;
        var j = 0;

        while (i < stringArray.size() and j < termArray.size()) {
            if (stringArray[i] == termArray[j]) {
                i += 1;
                j += 1;
                if (j == termArray.size()) { return true; }
            } else {
                i += 1;
                j := 0;
            }
        };
        false
    };

    public func toLowerCase(value: Text) : Text {
        let chars = Text.toIter(value);
        var lower = "";
        for (c: Char in chars) {
        lower := Text.concat(lower, Char.toText(Prim.charToLower(c)));
        };
        return lower;
    };
    
    public func nat32ToInt(value: Nat32): Int {
        let int32 = Int32.fromNat32(value);
        Int32.toInt(int32);
    };

    public func natToInt(value: Nat): Int {
        let nat64 = Nat64.fromNat(value);
        let int64 = Int64.fromNat64(nat64);
        Int64.toInt(int64);
    };

    public func textToNat32( txt : Text) : Nat32 {
        assert(txt.size() > 0);
        let chars = txt.chars();

        var num : Nat32 = 0;
        for (v in chars){
            let charToNum = Char.toNat32(v)-48;
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  charToNum;          
        };

        num;
    };

    public func textToNat( txt : Text) : Nat {
        assert(txt.size() > 0);
        let chars = txt.chars();

        var num : Nat = 0;
        for (v in chars){
            let charToNum = Char.toNat32(v)-48;
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  Nat32.toNat(charToNum);          
        };

        num;
    };

    public func _metaDataToJson(token1: Text, token2: Text): JSON {
        let map : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
            0,
            Text.equal,
            Text.hash,
        );
        map.put("token1", #String(token1));
        map.put("token2", #String(token2));
        #Object(map);
        
    };

     public func _transactionToJson(transaction: Transaction): JSON {
        let transactionHashMap : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
            0,
            Text.equal,
            Text.hash,
        );
        transactionHashMap.put("sender", #String(transaction.sender));
        transactionHashMap.put("receiver", #String(transaction.receiver));
        transactionHashMap.put("amount", #Number(transaction.amount));
        transactionHashMap.put("fee", #Number(transaction.fee));
        transactionHashMap.put("timeStamp", #Number(transaction.timeStamp));
        transactionHashMap.put("hash", #String(transaction.hash));
        transactionHashMap.put("transactionType", #String(transaction.transactionType));

        #Object(transactionHashMap);
    };

    public func _transactionToHash(transaction: Transaction): Text {
        let json = _transactionToJson(transaction);
        let sum256 = SHA256.sum(Blob.toArray(Text.encodeUtf8(JSON.show(json))));
        Hex.encode(sum256);
    };

    public func _putTransacton(canisterid:Text,amount:Int, sender:Text, receiver:Text, tax:Int, transactionType:Text) : async Text {
        let now = Time.now();

        let _transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = "";
            transactionType = transactionType;
        };

        let hash = _transactionToHash(_transaction);

        let transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = hash;
            transactionType = transactionType;
        };

        let _canisters = await DatabaseService.getCanistersByPK(canisterid,"group#ledger");
        let canisters = List.fromArray<Text>(_canisters);
        let exist = List.last(canisters);

        switch(exist){
            case(?exist){
                return await DatabaseService.putTransaction(exist,transaction);
            };
            case(null){
                return "";
            };
        };
    };
}