import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Principal "mo:base/Principal";

module Types {
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      GENERIC    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    
    public type Result<T, E> = Result.Result<T, E>;
    public let token_symbol : Text = "MBT";
    public let token_desc : Text = " MBT tokens";
    public type SystemParams = {
        transfer_fee : Tokens;
        // The amount of tokens needed to vote "yes" to accept, or "no" to reject, a proposal
        proposal_vote_threshold : Tokens;
        // The amount of tokens that will be temporarily deducted from the account of
        // a user that submits a proposal. If the proposal is Accepted, this deposit is returned,
        // otherwise it is lost. This prevents users from submitting superfluous proposals.
        proposal_submission_deposit : Tokens;
        // TODO: Add minimum staking amount parameter
    };
    public let defaulSystemParams : SystemParams = {
        transfer_fee : Tokens = {
            amount_e8s = 10_000
        };
        proposal_vote_threshold : Tokens = {
            amount_e8s = 100_000
        };
        proposal_submission_deposit : Tokens = {
            amount_e8s = 10_000
        }
    };
    public let oneToken = { amount_e8s = 100_000 };
    public let zeroToken = { amount_e8s = 0 };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     ACCOUNTS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // User accounts with the tokens that they hold
    public type Tokens = { amount_e8s : Nat };
    public type Account = { owner : Principal; tokens : Tokens };
    public type Subaccount = Blob;
    public type AccountIdentifier = Blob;
    public type TransferArgs = {
        to : Principal;
        amount : Tokens;
        duration : Nat
    };
    public type StakeArgs = { amount : Tokens; duration : Nat };
    public type NeuronState = {
        #Locked;
        #Dissolving;
        #Dissolved
    };
    public type Neuron = {
        owner : Principal;
        amount : Nat;
        // The staked duration
        dissolveDelay : Nat;
        neuronState : NeuronState;
        createdAt : Int;
        dissolvedAt : Int;
        // depositSubaccount : Subaccount
    };
    public type Neurons = [Neuron];
    public type StakedBalance = {
        balance : Tokens;
        neurons : Neurons;
        message : Text
    };

    // Get the account key
    public func account_key(t : Principal) : Trie.Key<Principal> = {
        key = t;
        hash = Principal.hash t
    };
    
    // Get the trie map from an accounts array.
    public func accounts_fromArray(arr : ?[Account]) : Trie.Trie<Principal, Tokens> {
        var s = Trie.empty<Principal, Tokens>();

        switch (arr) {
            case null { s };
            case (?accounts) {
                for (account in accounts.vals()) {
                    s := Trie.put(s, account_key(account.owner), Principal.equal, account.tokens).0
                };

                return s
            }
        }
    };

    // Prepare the response payload for notifying a user of their staked balance.
    public func prepare_staked_balance_response(balance : Tokens, neurons : Neurons, message : Text) : StakedBalance {
        return {
            balance = balance;
            neurons = neurons;
            message = message
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    PROPOSALS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // The proposal definition
    public type Proposal = {
        // Unique ID
        id : Nat;
        // Count of "no" votes
        votes_no : Tokens;
        // List of voters
        voters : List.List<Principal>;
        state : ProposalState;
        timestamp : Int;
        proposer : Principal;
        // Count of "yes" votes
        votes_yes : Tokens;
        payload : ProposalPayload
    };
    public type ProposalPayload = {
        canister_id : Principal;
        canister_method : Text;
        canister_message : Blob;
        proposal_summary : Text
    };
    public type ProposalState = {
        // A failure occurred while executing the proposal
        #failed : Text;
        // The proposal is open for voting
        #open;
        // The proposal is currently being executed
        #executing;
        // Enough "no" votes have been cast to reject the proposal, and it will not be executed
        #rejected;
        // The proposal has been successfully executed
        #succeeded;
        // Enough "yes" votes have been cast to accept the proposal, and it will soon be executed
        #accepted
    };

    // Get the proposal key.
    public func proposal_key(t : Nat) : Trie.Key<Nat> = {
        key = t;
        hash = Int.hash t
    };

    // Get the trie map from a proposals array.
    public func proposals_fromArray(arr : ?[Proposal]) : Trie.Trie<Nat, Proposal> {
        var s = Trie.empty<Nat, Proposal>();

        switch (arr) {
            case null { s };
            case (?proposals) {
                for (proposal in proposals.vals()) {
                    s := Trie.put(s, proposal_key(proposal.id), Nat.equal, proposal).0
                };

                return s
            }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      VOTING     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    public type Vote = { #no; #yes };
    public type VoteArgs = { vote : Vote; proposal_id : Nat };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    BOOTSTRAP    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    public type UpdateSystemParamsPayload = {
        transfer_fee : ?Tokens;
        proposal_vote_threshold : ?Tokens;
        proposal_submission_deposit : ?Tokens
    };
    public type BasicDaoStableStorage = {
        accounts : [Account];
        proposals : [Proposal];
        system_params : SystemParams
    };
}
