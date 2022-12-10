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
import TxReceipt "../models/TxReceipt"

actor class Swap(
    _token1: Principal,
    _token2: Principal,
    ) = this{


  private type TxReceipt = TxReceipt.TxReceipt;
  
  private let precision = 100000000;
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

  public func price(): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    _price(totalToken1,totalToken2);
  };

  public query func getShares(owner:Principal): async Nat {
    _getShares(owner)
  };

  public shared({caller}) func provide(amountToken1:Nat, amountToken2:Nat): async TxReceipt {
    await _provide(caller,amountToken1, amountToken2)
  };

  public shared({caller}) func withdraw(share:Nat): async TxReceipt {
    await _withdraw(caller,share);
  };

  public func getWithdrawEstimate(share:Nat): async {share1:Nat;share2:Nat} {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    await _getWithdrawEstimate(share,totalToken1,totalToken2)
  };

  public shared({caller}) func swapToken1(amountToken1:Nat, slippage:Nat): async TxReceipt{
    await _swapToken1(caller,amountToken1,slippage)
  };

  public func getSwapToken1Estimate(amountToken1:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    _getSwapToken1Estimate(amountToken1,totalToken1,totalToken2)
  };

  public func getSwapToken1EstimateGivenToken2(amountToken2:Nat): async TxReceipt {
    await _getSwapToken1EstimateGivenToken2(amountToken2)
  };

  public shared({caller}) func swapToken2(amountToken2:Nat,slippage:Nat): async TxReceipt{
    await _swapToken2(caller,amountToken2,slippage)
  };

  public func getSwapToken2Estimate(amountToken2:Nat): async Nat {
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    _getSwapToken2Estimate(amountToken2,totalToken1,totalToken2)
  };

  public func getSwapToken2EstimateGivenToken1(amountToken1:Nat): async TxReceipt {
    await _getSwapToken2EstimateGivenToken1(amountToken1)
  };

  public func getEquivalentToken1Estimate(amountToken2:Nat): async Nat {
    await _getEquivalentToken1Estimate(amountToken2)
  };

  public func getEquivalentToken2Estimate(amountToken1:Nat): async Nat {
    await _getEquivalentToken2Estimate(amountToken1)
  };

  ///////////////PRIVATE/////////////////////////

  private func _price(totalToken1:Nat,totalToken2:Nat): Nat {
    // Algorithmic constant used to determine price (K = totalToken1 * totalToken2)
    let _this = Principal.fromActor(this);
    totalToken1 * totalToken2
  };

  private func _provide(from:Principal,amountToken1:Nat, amountToken2:Nat): async TxReceipt {
    let _this = Principal.fromActor(this);
    var share:Nat = 0;
    if(totalShares == 0){
      share := 100*precision;
    }else {
      let totalToken1 = await _tokenBalance(token1,_this);
      let totalToken2 = await _tokenBalance(token2,_this);
      assert(totalToken1 > 0 and totalToken2 > 0); 
      let isValid1 = await _isValid(from,amountToken1,token1);
      let isValid2 = await _isValid(from,amountToken2,token2);
      assert(isValid1 and isValid2);
      let share1 = Nat.div(Nat.mul(totalShares,amountToken1),totalToken1);
      let share2 = Nat.div(Nat.mul(totalShares,amountToken2),totalToken2);
      assert(share1 == share2);
      share := share1;
    };
    assert(share > 0);
    let receipt1 = await _transferFrom(from,_this,amountToken1,token1);
    switch(receipt1){
      case(#Ok(value)){
        let receipt2 = await _transferFrom(from,_this,amountToken2,token2);
        switch(receipt2){
          case(#Ok(value)){
            _addShares(from,share);
            #Ok(0);
          };
          case(#Err(value)){
            #Err(value)
          }
        }
      };
      case(#Err(value)){
        #Err(value)
      }
    }
  };

  private func _withdraw(to:Principal,share:Nat): async TxReceipt {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    assert(totalToken1 > 0 and totalToken2 > 0); 
    let shares = _getShares(to);
    assert(shares >= share);
    let withdrawEstimate = await _getWithdrawEstimate(share,totalToken1,totalToken2);
    assert(withdrawEstimate.share1 > 0 and withdrawEstimate.share2 > 0);
    assert(totalToken1 > withdrawEstimate.share1);
    assert(totalToken2 > withdrawEstimate.share2);
    let receipt1 = await _transfer(to,withdrawEstimate.share1,token1);
    switch(receipt1){
      case(#Ok(value)){
        let receipt2 = await _transfer(to,withdrawEstimate.share2,token2);
        switch(receipt2){
          case(#Ok(value)){
            _removeShares(to,share);
            #Ok(0)
          };
          case(#Err(value)){
            return #Err(value)
          };
        };
      };
      case(#Err(value)){
        return #Err(value)
      };
    };
  };

  private func _getWithdrawEstimate(share:Nat,totalToken1:Nat,totalToken2:Nat): async {share1:Nat;share2:Nat} {
    assert(totalShares > 0);
    assert(share <= totalShares);
    let _this = Principal.fromActor(this);

    let share1 = Nat.div(Nat.mul(share,totalToken1),totalShares);
    let share2 = Nat.div(Nat.mul(share,totalToken2),totalShares);

    {
      share1 = share1;
      share2 = share2
    }
  };

  // Returns amount of Token1 required when providing liquidity with _amountToken2 quantity of Token2
  private func _getEquivalentToken1Estimate(amountToken2:Nat): async Nat {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    Nat.div(Nat.mul(totalToken1,amountToken2),totalToken2)
  };

  // Returns amount of Token2 required when providing liquidity with _amountToken1 quantity of Token1
  private func _getEquivalentToken2Estimate(amountToken1:Nat): async Nat {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    Nat.div(Nat.mul(totalToken2,amountToken1),totalToken1)

  };

  // Swaps given amount of Token1 to Token2 using algorithmic price determination
  private func _swapToken1(from:Principal,amountToken1:Nat,slippage:Nat): async TxReceipt {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let amountToken2 = _getSwapToken1Estimate(amountToken1,totalToken1,totalToken2);
    if(amountToken2 <= slippage){
      return #Err(#Slippage(amountToken2));
    };
    assert(totalToken2 > 0); 
    let isValid = await _isValid(from,amountToken1,token1);
    assert(totalToken2 > amountToken2);
    assert(isValid);
    let receipt = await _transferFrom(from,_this,amountToken1,token1);
    switch(receipt){
      case(#Ok(value)){
        let receipt2 = await _transfer(from,amountToken2,token2);
        switch(receipt2){
          case(#Ok(value)){
            return #Ok(amountToken2)
          };
          case(#Err(value)){
            return #Err(value)
          }
        };
        #Ok(amountToken2)
      };
      case(#Err(value)){
        #Err(value)
      }
    };

  };

  // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
  private func _getSwapToken1Estimate(amountToken1:Nat,totalToken1:Nat, totalToken2:Nat): Nat {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let price = _price(totalToken1,totalToken2);
    
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
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let price = _price(totalToken1,totalToken2);
    if(totalToken2 < amountToken2){
      return #Err(#InsufficientPoolBalance);
    };

    let token2After = Nat.sub(totalToken2,amountToken2);
    let token1After = Nat.div(price,token2After);
    let amountToken1 = Nat.sub(token1After,totalToken1);
    #Ok(amountToken1);
  };

   // Swaps given amount of Token2 to Token1 using algorithmic price determination
  private func _swapToken2(from:Principal,amountToken2:Nat,slippage:Nat): async TxReceipt {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    let amountToken1 = _getSwapToken2Estimate(amountToken2,totalToken1,totalToken2);
    if(amountToken2 <= slippage){
      return #Err(#Slippage(amountToken2));
    };
    assert(totalToken1 > 0); 
    let isValid = await _isValid(from,amountToken2,token2);
    assert(totalToken1 > amountToken1);
    assert(isValid);
    let receipt = await _transferFrom(from,_this,amountToken2,token2);
    switch(receipt){
      case(#Ok(value)){
        let receipt2 = await _transfer(from,amountToken1,token1);
        switch(receipt2){
          case(#Ok(value)){
            #Ok(amountToken1)
          };
          case(#Err(value)){
            #Err(value)
          }
        };
      };
      case(#Err(value)){
        #Err(value)
      }
    };
  };

   // Returns the amount of Token2 that the user will get when swapping a given amount of Token1 for Token2
  private func _getSwapToken2Estimate(amountToken2:Nat,totalToken1:Nat,totalToken2:Nat): Nat {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let price = _price(totalToken1,totalToken2);

    let token2After = Nat.add(totalToken2,amountToken2);
    let token1After = Nat.div(price,token2After);

    var amountToken1 = Nat.sub(totalToken1,token1After);

    // To ensure that Token2's pool is not completely depleted
    if(amountToken1 == totalToken1) {
      amountToken1 := amountToken1 - 1;
    };
    amountToken1
  };

  // Returns the amount of Token2 that the user should swap to get _amountToken1 in return
  private func _getSwapToken2EstimateGivenToken1(amountToken1:Nat): async TxReceipt {
    assert(totalShares > 0);
    let _this = Principal.fromActor(this);
    let totalToken1 = await _tokenBalance(token1,_this);
    let totalToken2 = await _tokenBalance(token2,_this);
    if(totalToken1 < amountToken1){
      return #Err(#InsufficientPoolBalance);
    };
    let price = _price(totalToken1,totalToken2);
    let token1After = Nat.sub(totalToken1,amountToken1);
    let token2After = Nat.div(price,token1After);
    let amountToken2 = Nat.sub(token2After,totalToken2);
    #Ok(amountToken2);
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

  private func _tokenBalance(token:Principal,owner:Principal,): async Nat {
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

  private func _getShares(owner:Principal): Nat {
    let exist = shares.get(owner);
    switch(exist){
      case(?exist){
        exist
      };
      case(null){
        0
      };
    };
  };

  private func _isValid(sender:Principal, amount:Nat, token:Principal): async Bool {

    let _this = Principal.fromActor(this);
    let totalSenderTokens = await _tokenBalance(token,sender);
    let allowance = await _allowance(sender,token);

    amount > 0 and totalSenderTokens >= amount and allowance >= amount;

  };

  public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));

        if (path.size() == 1) {
            switch (path[0]) {
                case ("getMetaData") return _getMetaDataResponse();
                case (_) return return Http.BAD_REQUEST();
            };
        }else {
            return Http.BAD_REQUEST();
        };
    };

    private func _natResponse(value : Nat): Http.Response {
        let json = #Number(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response: Http.Response = {
            status_code        = 200;
            headers            = [("Content-Type", "application/json")];
            body               = blob;
            streaming_strategy = null;
        };
    };

    private func _getMetaDataResponse(): Http.Response {
        let json = Utils._metaDataToJson(Principal.toText(token1), Principal.toText(token2));
        let blob = Text.encodeUtf8(JSON.show(json));
        let response: Http.Response = {
            status_code        = 200;
            headers            = [("Content-Type", "application/json")];
            body               = blob;
            streaming_strategy = null;
        };
    };


};
