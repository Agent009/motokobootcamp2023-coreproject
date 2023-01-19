actor {
    stable var currentValue: Nat = 0;
    
    // dfx canister call webpage increment
    public func increment(): async () {
        currentValue += 1;
    };

    // dfx canister call webpage getValue
    public query func getValue(): async Nat {
        currentValue;
    };
};
