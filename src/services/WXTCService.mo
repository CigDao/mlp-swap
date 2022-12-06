import Constants "../Constants";
import Result "mo:base/Result";

module {

    public type TxError = {
        #InsufficientAllowance;
        #InsufficientBalance;
        #ErrorOperationStyle;
        #Unauthorized;
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

    public let canister = actor(Constants.WXTC_Canister) : actor { 
        mint_by_icp: (?Blob, Nat64) -> async TxReceipt;
        burn: (BurnRequest) -> async TxReceipt;
        balanceOf: (Principal) -> async Nat;
    };
}