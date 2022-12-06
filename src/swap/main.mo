import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Array "mo:base/Array";
import List "mo:base/List";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Constants "../Constants";
import Utils "../helpers/Utils";
import JSON "../helpers/JSON";
import Http "../helpers/http";
import Response "../models/Response";
import Cycles "mo:base/ExperimentalCycles";
import Prim "mo:prim";
import TokenService "../services/TokenService";


actor class Swap(
    _token1: Principal,
    _token2: Principal,
    ) = this{

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

  private stable var totalShares = 0;
  private stable var token1 = _token1;
  private stable var token2 = _token2;

  private stable var shareEntries : [(Principal,Nat)] = [];
  private var shares = HashMap.fromIter<Principal,Nat>(shareEntries.vals(), 0, Principal.equal, Principal.hash);

  system func preupgrade() {
    shareEntries := Iter.toArray(shares.entries());
  };

  system func postupgrade() {
    shareEntries := [];
  };

  public query func getMemorySize(): async Nat {
      let size = Prim.rts_memory_size();
      size;
  };

  public query func getHeapSize(): async Nat {
      let size = Prim.rts_heap_size();
      size;
  };

  public query func getCycles(): async Nat {
      Cycles.balance();
  };

  private func _getMemorySize(): Nat {
      let size = Prim.rts_memory_size();
      size;
  };

  private func _getHeapSize(): Nat {
      let size = Prim.rts_heap_size();
      size;
  };

  private func _getCycles(): Nat {
      Cycles.balance();
  };

  public shared({caller}) func swapToken1(amountToken1:Nat): async {
    await _swapToken1(caller,amountToken1)
  };

  public shared({caller}) func swapToken2(amountToken2:Nat): async {
    await _swapToken2(caller,amountToken2)
  };

  private func _price(): async Nat {
    // Algorithmic constant used to determine price (K = totalToken1 * totalToken2)
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    totalToken1 * totalToken2
  };

  private func _provide(from:Principal,amountToken1:Nat, amountToken2:Nat): async () {
    let _this = Principal.fromActor(this);
    var share:Nat = 0;
    if(totalShares == 0){
      share := 0;
    }else {
      let totalToken1 = await _tokenBalance(token1,_this);
      let totalToken2 = await _tokenBalance(token2,_this);
      let share1 = Nat.div(Nat.mul(totalShares,amountToken1),totalToken1);
      let share2 = Nat.div(Nat.mul(totalShares,amountToken2),totalToken2);
      assert(share1 == share2);
      share := share1;
    };
    assert(share > 0);
    let receipt1 = await _transferFrom(from,_this,amountToken1,token1);
    let receipt2 = await _transferFrom(from,_this,amountToken2,token2);
    _addShares(from,share)

  };

  private func _withdraw(to:Principal,share:Nat): async TxReceipt {
    let withdrawEstimate = await _getWithdrawEstimate(share);
    _removeShares(to,share);
    ignore await _transfer(to,withdrawEstimate.share1,token1);
    await _transfer(to,withdrawEstimate.share2,token2);
  };

  private func _getWithdrawEstimate(share:Nat): async {share1:Nat;share2:Nat}{
    assert(share <= totalShares);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);

    let share1 = Nat.div(Nat.mul(share,totalToken1),totalShares);
    let share2 = Nat.div(Nat.mul(share,totalToken2),totalShares);

    {
      share1 = share1;
      share2 = share2
    }
  };

  private func _getEquivalentToken1Estimate(amountToken2:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    Nat.div(Nat.mul(totalToken1,amountToken2),totalToken2)
  };

  private func _getEquivalentToken2Estimate(amountToken1:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    Nat.div(Nat.mul(totalToken2,amountToken1),totalToken1)

  };


  // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
  private func _getSwapToken1Estimate(amountToken1:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let price = await _price();

    let token1After = Nat.add(totalToken1,amountToken1);
    let token2After = Nat.div(price,token1After);

    var amountToken2 = Nat.sub(totalToken2,token2After);

    // To ensure that Token2's pool is not completely depleted
    if(amountToken2 == totalToken2) {
      amountToken2 := amountToken2 - 1;
    };
    amountToken2
  };

  // Returns the amount of Token1 that the user should swap to get _amountToken2 in return
  private func _getSwapToken1EstimateGivenToken2(amountToken2:Nat): async TxReceipt {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let price = await _price();
    if(totalToken2 < amountToken2){
      return #Err(#InsufficientAllowance);
    };

    let token2After = Nat.sub(totalToken2,amountToken2);
    let token1After = Nat.div(price,token2After);
    let amountToken1 = Nat.sub(token1After,totalToken1);
    #Ok(amountToken1);
  };

  // Swaps given amount of Token1 to Token2 using algorithmic price determination
  private func _swapToken1(from:Principal,amountToken1:Nat): async TxReceipt {
    let _this = Principal.fromActor(this);
    let amountToken2 = await _getSwapToken1Estimate(amountToken1);
    ignore await _transferFrom(from,_this,amountToken1,token1);
    await _transfer(from,amountToken2,token2);

  };

   // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
  private func _getSwapToken2Estimate(amountToken2:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let price = await _price();

    let token2After = Nat.add(totalToken2,amountToken2);
    let token1After = Nat.div(price,token2After);

    var amountToken1 = Nat.sub(totalToken1,token1After);

    // To ensure that Token2's pool is not completely depleted
    if(amountToken1 == totalToken1) {
      amountToken1 := amountToken1 - 1;
    };
    amountToken2
  };

  // Returns the amount of Token2 that the user should swap to get _amountToken1 in return
  private func _getSwapToken2EstimateGivenToken2(amountToken1:Nat): async TxReceipt {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let price = await _price();
    if(totalToken1 < amountToken1){
      return #Err(#InsufficientAllowance);
    };

    let token1After = Nat.sub(totalToken1,amountToken1);
    let token2After = Nat.div(price,token1After);
    let amountToken2 = Nat.sub(token2After,totalToken2);
    #Ok(amountToken2);
  };

  // Swaps given amount of Token1 to Token1 using algorithmic price determination
  private func _swapToken2(from:Principal,amountToken2:Nat): async TxReceipt {
    let _this = Principal.fromActor(this);
    let amountToken1 = await _getSwapToken2Estimate(amountToken2);
    ignore await _transferFrom(from,_this,amountToken2,token2);
    await _transfer(from,amountToken1,token1);

  };

  private func _transferFrom(from:Principal,to:Principal,amount:Nat,token:Principal): async TxReceipt {
    let canister = Principal.toText(token);
    await TokenService.transferFrom(from,to,amount,canister)
  };

  private func _transfer(to:Principal,amount:Nat,token:Principal): async TxReceipt {
    let canister = Principal.toText(token);
    await TokenService.transfer(to,amount,canister)
  };

  private func _allowance(owner:Principal,token:Principal): async Nat {
    let canister = Principal.toText(token);
    let _this = Principal.fromActor(this);
    await TokenService.allowance(owner,_this,canister)
  };

  private func _tokenBalance(owner:Principal,token:Principal): async Nat {
    let canister = Principal.toText(token);
    await TokenService.balanceOf(owner,canister)
  };

  private func _addShares(owner:Principal,share:Nat) {
    let exist = shares.get(owner);
    totalShares := totalShares + share;
    switch(exist){
      case(?exist){
        let _share = exist + share;
        shares.put(owner,_share)
      };
      case(null){
        shares.put(owner,share)
      };
    };
  };

  private func _removeShares(owner:Principal,share:Nat) {
    let exist = shares.get(owner);
    switch(exist){
      case(?exist){
        totalShares := totalShares - share;
        var _share = exist - share;
        shares.put(owner,_share)
      };
      case(null){

      };
    };
  };

  private func isValid(amount:Nat, sender:Principal, token:Principal): async Bool {

    let _this = Principal.fromActor(this);
    let totalSenderTokens = await _tokenBalance(token,sender);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let allowance = await _allowance(sender,token);

    totalToken1 > 0 and totalToken2 > 0 and amount > 0 and totalSenderTokens >= amount and allowance >= amount;

  };

};
