import Transaction "../models/Transaction";
import Constants "../Constants";

module {

    private type Transaction = Transaction.Transaction;

    public func putTransaction(canisterId:Text,transaction:Transaction) : async Text {
        let canister = actor(canisterId) : actor { 
            putTransaction: (Transaction)  -> async Text;
        };

        await canister.putTransaction(transaction);
    };

    public let canister = actor(Constants.databaseCanister) : actor { 
        getCanistersByPK: (Text) -> async [Text]; 
    };
}
