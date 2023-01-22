import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Principal "mo:base/Principal";

module Types {
  public type Result<T, E> = Result.Result<T, E>;
  // User accounts with the tokens that they hold
  public type Account = { owner : Principal; tokens : Tokens };
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
    payload : ProposalPayload;
  };
  public type ProposalPayload = {
    canister_id : Principal;
    canister_method : Text;
    canister_message : Blob;
    proposal_summary : Text;
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
      #accepted;
  };
  public type Tokens = { amount_e8s : Nat };
  public type TransferArgs = { to : Principal; amount : Tokens };
  public type UpdateSystemParamsPayload = {
    transfer_fee : ?Tokens;
    proposal_vote_threshold : ?Tokens;
    proposal_submission_deposit : ?Tokens;
  };
  public type Vote = { #no; #yes };
  public type VoteArgs = { vote : Vote; proposal_id : Nat };

  public type SystemParams = {
    transfer_fee: Tokens;

    // The amount of tokens needed to vote "yes" to accept, or "no" to reject, a proposal
    proposal_vote_threshold: Tokens;

    // The amount of tokens that will be temporarily deducted from the account of
    // a user that submits a proposal. If the proposal is Accepted, this deposit is returned,
    // otherwise it is lost. This prevents users from submitting superfluous proposals.
    proposal_submission_deposit: Tokens;
  };
  public let defaulSystemParams : SystemParams = {
    transfer_fee: Tokens = {
        amount_e8s = 10_000
    };
    proposal_vote_threshold: Tokens = {
        amount_e8s = 10_000_000
    };
    proposal_submission_deposit: Tokens = {
        amount_e8s = 10_000
    };
  };
  public type BasicDaoStableStorage = {
    accounts: [Account];
    proposals: [Proposal];
    system_params: SystemParams;
  };
  public type NeuronState = {
    #Locked;
    #Dissolving;
    #Dissolved;
  };
  public type Neuron = {
    owner: Principal;
    amount: Nat;
    dissolveDelay: Int;
    neuronState: NeuronState;
    createdAt: Int;
    dissolvedAt: Int;
    depositSubaccount: Subaccount;
  };

  public type Subaccount = Blob;

  public func proposal_key(t: Nat) : Trie.Key<Nat> = { key = t; hash = Int.hash t };
  public func account_key(t: Principal) : Trie.Key<Principal> = { key = t; hash = Principal.hash t };
  public func accounts_fromArray(arr: ?[Account]) : Trie.Trie<Principal, Tokens> {
    var s = Trie.empty<Principal, Tokens>();

    switch (arr) {
        case null { s };
        case (?accounts) {
            for (account in accounts.vals()) {
                s := Trie.put(s, account_key(account.owner), Principal.equal, account.tokens).0;
            };

            return s;
        };
    };
  };

  public func proposals_fromArray(arr: ?[Proposal]) : Trie.Trie<Nat, Proposal> {
    var s = Trie.empty<Nat, Proposal>();

    switch (arr) {
        case null { s };
        case (?proposals) {
            for (proposal in proposals.vals()) {
                s := Trie.put(s, proposal_key(proposal.id), Nat.equal, proposal).0;
            };

            return s;
        };
    };
  };
  
  public let oneToken = { amount_e8s = 10_000_000 };
  public let zeroToken = { amount_e8s = 0 };  
}
