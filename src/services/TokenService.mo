import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";

module {

    public type TxReceipt = {
        #Ok: Nat;
        #Err: {
            #InsufficientAllowance;
            #InsufficientBalance;
            #ErrorOperationStyle;
            #Unauthorized;
            #LedgerTrap;
            #ErrorTo;
            #Other: Text;
            #BlockUsed;
            #ActiveProposal;
            #AmountTooSmall;
        };
    };

    public func allowance(owner:Principal, spender:Principal, canister:Text): async Nat {
        await _canister(canister).allowance(owner, spender);
    };

    public func transfer(to:Principal, amount:Nat, canister:Text): async TxReceipt {
        await _canister(canister).transfer(to, amount);
    };

    public func communityTransfer(to:Principal, amount:Nat, canister:Text): async TxReceipt {
        await _canister(canister).communityTransfer(to, amount);
    };

    public func transferFrom(from:Principal, to:Principal, amount:Nat, canister:Text): async TxReceipt {
        await _canister(canister).transferFrom(from, to, amount);
    };

    public func totalSupply(canister:Text): async Nat {
        await _canister(canister).totalSupply();
    };

    public func balanceOf(owner:Principal,canister:Text): async Nat {
        await _canister(canister).balanceOf(owner);
    };

    private func _canister(canister:Text): actor { 
            allowance : shared query (Principal, Principal) -> async Nat;
            transfer: (Principal, Nat)  -> async TxReceipt;
            balanceOf: (Principal)  -> async Nat;
            transferFrom : shared (Principal, Principal, Nat) -> async TxReceipt;
            chargeTax : shared (Principal, Nat) -> async (TxReceipt);
            updateTransactionPercentage : shared (Float) -> async ();
            totalSupply : shared query () -> async Nat;
            communityTransfer: (Principal, Nat)  -> async TxReceipt;
        }{
        return actor(Constants.dip20Canister) : actor { 
            allowance : shared query (Principal, Principal) -> async Nat;
            transfer: (Principal, Nat)  -> async TxReceipt;
            balanceOf: (Principal)  -> async Nat;
            transferFrom : shared (Principal, Principal, Nat) -> async TxReceipt;
            chargeTax : shared (Principal, Nat) -> async (TxReceipt);
            updateTransactionPercentage : shared (Float) -> async ();
            totalSupply : shared query () -> async Nat;
            communityTransfer: (Principal, Nat)  -> async TxReceipt;
        };
    };
}