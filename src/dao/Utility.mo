import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import CRC32 "./CRC32";
import SHA224 "./SHA224";
import Types "./Types";

module Utility {
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     ACCOUNTS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    // Ref: https://github.com/motoko-bootcamp/motokobootcamp-2023/blob/main/daily_guides/day_4/GUIDE.MD#accounts
    // Accounts are large integers (represented as 32-byte strings) which represent a unique wallet that can hold assets on The Ledger canister.
    // To derive an account from a Principal, you need what's called a "subaccount".
    // You need both a Principal and Subaccount to get an Account: func accountIdentifier(principal: Principal, subaccount: Subaccount) : AccountIdentifier
    // A subaccount is also a large integer (which could also be represented as a 32-byte string), but it's easier to think of them almost as a "counter".
    // For any Principal, we refer to the account which corresponds to the subaccount which is equal to 0 as the default account of that principal.
    // f you wanted to generate another account for that Principal, then you could use the subaccount which is equal to 1 to generate another Account.
    // You could even pick any random 32-byte number, and then use it to get an account which could be controlled by that Principal.
    // There are a lot of Accounts which could be generated for a Principal, because a 32-bit unsigned integer has a maximum value of 4,294,967,295.
    let anonPrincipalID : Text = "2vxsx-fae";

    // Return TRUE if the specified principal is an anonymous user.
    // Anonymous id is 0x04, an this is the "default caller" encountered when an unauthenticated user calls functions.
    public func isAnon(p : Principal) : Bool {
        Principal.equal(p, Principal.fromText(anonPrincipalID)) or Principal.isAnonymous(p)
    };

    // Return TRUE if the specific principal belongs to a canister.
    // Opaque ids are the class of Principals used for canisters.
    // Canister Principals are shorter than user Principals, and they end with "-cai".
    // Ref: https://internetcomputer.org/docs/current/references/ic-interface-spec#id-classes
    // Ref: https://github.com/motoko-bootcamp/motokobootcamp-2023/blob/main/daily_guides/day_4/GUIDE.MD#principals
    public func isCanisterPrincipal(p : Principal) : Bool {
        let principal_text = Principal.toText(p);
        let correct_length = Text.size(principal_text) == 27;
        let correct_last_characters = Text.endsWith(principal_text, #text "-cai");

        if (Bool.logand(correct_length, correct_last_characters)) {
            return true
        };
        return false
    };

    // Get the sub account for the given principal.
    // A canister has it's own Principal, and it often needs to store and control assets (such as tokens or NFTs) on behalf of users (who also have their own Principal).
    // A common practice is to convert the Principal of a user into a subaccount, then to use that subaccount to derive an Account (unique to that user) which the canister can control.
    // Ref: https://github.com/motoko-bootcamp/motokobootcamp-2023/blob/main/daily_guides/day_4/GUIDE.MD#principals
    private func getSubAccountForPrincipal(p : Principal) : [Nat8] {
        let buffer = Buffer.Buffer<Nat8>(0);

        for (nat8 in Blob.toArray(Text.encodeUtf8(Principal.toText(p))).vals()) {
            if (buffer.size() < 32) {
                buffer.add(nat8)
            }
        };

        Buffer.toArray(buffer)
    };

    // Alternative implementation, which requires a few external libraries.
    // public func getSubAccountForPrincipal(principal : Principal) : Blob {
    //     let idHash = SHA224.Digest();
    //     idHash.write(Blob.toArray(Principal.toBlob(principal)));
    //     let hashSum = idHash.sum();
    //     let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
    //     let buf = Buffer.Buffer<Nat8>(32);
    //     let blob = Blob.fromArray(Array.append(crc32Bytes, hashSum));

    //     return blob
    // }

    // Combine the Principal (such as the canister's principal) with a subaccount (such as a user) to create an Account which is represented as a Blob
    // getAccountIdentifier(Principal.fromActor(Self), getDefaultSubaccount())
    public func getAccountIdentifier(principal : Principal, subaccount : Types.Subaccount) : Types.AccountIdentifier {
        let hash = SHA224.Digest();
        hash.write([0x0A]);
        hash.write(Blob.toArray(Text.encodeUtf8("account-id")));
        hash.write(Blob.toArray(Principal.toBlob(principal)));
        hash.write(Blob.toArray(subaccount));
        let hashSum = hash.sum();
        let crc32Bytes = beBytes(CRC32.ofArray(hashSum));
        Blob.fromArray(Array.append(crc32Bytes, hashSum))
    };

    // https://github.com/stephenandrews/motoko-accountid/blob/main/src/AccountId.mo
    func beBytes(n : Nat32) : [Nat8] {
        func byte(n : Nat32) : Nat8 {
            Nat8.fromNat(Nat32.toNat(n & 0xff))
        };

        [byte(n >> 24), byte(n >> 16), byte(n >> 8), byte(n)]
    };

    public func getDefaultSubaccount() : Types.Subaccount {
        Blob.fromArrayMut(Array.init(32, 0 : Nat8))
    };

    // Ref: https://github.com/dfinity/examples/blob/master/motoko/ledger-transfer/src/ledger_transfer/main.mo
    public func validateAccountIdentifier(accountIdentifier : Types.AccountIdentifier) : Bool {
        if (accountIdentifier.size() != 32) {
            return false
        };

        let a = Blob.toArray(accountIdentifier);
        let accIdPart = Array.tabulate(28, func(i : Nat) : Nat8 { a[i + 4] });
        let checksumPart = Array.tabulate(4, func(i : Nat) : Nat8 { a[i] });
        let crc32 = CRC32.ofArray(accIdPart);
        Array.equal(beBytes(crc32), checksumPart, Nat8.equal)
    };
}
