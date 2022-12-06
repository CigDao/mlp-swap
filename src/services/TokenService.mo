import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import TxReceipt "../models/TxReceipt";

module {

    public type TxReceipt = TxReceipt.TxReceipt;

    public func allowance(owner:Principal, spender:Principal, canister:Text): async Nat {
        let _canister = actor(canister) : actor { 
            allowance : shared query (Principal, Principal) -> async Nat;
        };

        await _canister.allowance(owner,spender);
    };

    public func transfer(to:Principal, amount:Nat, canister:Text): async TxReceipt {
        let _canister = actor(canister) : actor { 
            transfer: (Principal, Nat)  -> async TxReceipt;
        };

        await _canister.transfer(to,amount);
    };

    public func transferFrom(from:Principal, to:Principal, amount:Nat, canister:Text): async TxReceipt {
        let _canister = actor(canister) : actor { 
            transferFrom : shared (Principal, Principal, Nat) -> async TxReceipt;
        };

        await _canister.transferFrom(from,to,amount);
    };

    public func balanceOf(owner:Principal,canister:Text): async Nat {
        let _canister = actor(canister) : actor { 
            balanceOf: (Principal)  -> async Nat;
        };

        await _canister.balanceOf(owner);
    };
}