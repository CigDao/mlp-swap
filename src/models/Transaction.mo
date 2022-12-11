import Time "mo:base/Time";

module {

    public type Transaction = {
        sender:Text;
        receiver:Text;
        amount:Int;
        fee:Int;
        timeStamp:Time.Time;
        hash:Text;
        transactionType:Text;
    };
}