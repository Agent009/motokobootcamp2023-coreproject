actor {
    stable var currentValue: Nat = 0;
    
    // dfx canister call backend increment
    public func increment(): async () {
        currentValue += 1;
    };

    // dfx canister call backend getValue
    public query func getValue(): async Nat {
        currentValue;
    };
};
