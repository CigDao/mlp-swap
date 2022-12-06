import Constants "../Constants";
import Result "mo:base/Result";

module {

    public type TxError = {
        #InsufficientAllowance;
        #InsufficientBalance;
        #ErrorOperationStyle;
        #Unauthorized;
        #NoRound;
        #LedgerTrap;
        #ErrorTo;
        #Other;
        #BlockUsed;
        #FetchRateFailed;
        #NotifyDfxFailed;
        #UnexpectedCyclesResponse;
        #AmountTooSmall;
        #InsufficientXTCFee;
    };

    public type TxReceipt = {
        #Ok:Nat;
        #Err:TxError;
    };

    public type BurnRequest = {
        canister_id:Principal;
        amount:Nat64;
    };

    public let canister = actor(Constants.WICP_Canister) : actor { 
        mint : (?Blob, Nat64) -> async TxReceipt;
        withdraw : (Nat64, Text) -> async TxReceipt;
        balanceOf: (Principal) -> async Nat;
        allowance: (Principal,Principal) -> async Nat;
        transfer: (Principal, Nat) -> async TxReceipt;
        transferFrom: (Principal, Principal, Nat) -> async TxReceipt;
    };
}