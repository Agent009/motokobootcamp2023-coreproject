import Text "mo:base/Text";
import Map "mo:base/HashMap";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Error "mo:base/Error";
import ICRaw "mo:base/ExperimentalInternetComputer";
import List "mo:base/List";
import Time "mo:base/Time";
import Types "./Types";
import Debug "mo:base/Debug";

// DAO actor class with the capability to accept init bootstrap data.
// The init has been made optional, so that we can deploy without bootstrapping as well.
shared actor class DAO(init : ?Types.BasicDaoStableStorage) = Self {
    public type Proposal = Types.Proposal;
    stable var accounts = Types.accounts_fromArray(switch (init) { case null { null }; case (?i) { ?i.accounts } });
    stable var proposals = Types.proposals_fromArray(switch (init) { case null { null }; case (?i) { ?i.proposals } });
    stable var next_proposal_id : Nat = 0;
    stable var neuron_entries : [(Principal, Types.Neuron)] = [];
    let Ledger : actor { 
        icrc1_balance_of : (Types.Account) -> async Nat
    } = actor ("renrk-eyaaa-aaaaa-aaada-cai");
    let neurons = HashMap.fromIter<Principal, Types.Neuron>(neuron_entries.vals(), Iter.size(neuron_entries.vals()), Principal.equal, Principal.hash);
    stable var system_params : Types.SystemParams = switch (init) {
        case null { Types.defaulSystemParams };
        case (?i) { i.system_params }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    PROPOSALS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Submit a proposal
    //
    // A proposal contains a canister ID, method name and method args. If enough users
    // vote "yes" on the proposal, the given method will be called with the given method
    // args on the given canister.
    public shared ({ caller }) func submit_proposal(payload : Types.ProposalPayload) : async Types.Result<Nat, Text> {
        Debug.print("submit_proposal called by " # debug_show (caller));
        Debug.print("payload " # debug_show (payload));
        Result.chain(
            deduct_proposal_submission_deposit(caller),
            func(()) : Types.Result<Nat, Text> {
                let proposal_id = next_proposal_id;
                // Generate the next proposal ID
                next_proposal_id += 1;
                Debug.print("New proposal ID: " # debug_show (next_proposal_id));
                // Store the new proposal details
                let proposal : Types.Proposal = {
                    id = proposal_id;
                    timestamp = Time.now();
                    proposer = caller;
                    payload;
                    state = #open;
                    votes_yes = Types.zeroToken;
                    votes_no = Types.zeroToken;
                    voters = List.nil()
                };
                Debug.print("New proposal payload: " # debug_show (proposal));
                proposal_put(proposal_id, proposal);
                Debug.print("New proposal stored.");
                #ok(proposal_id)
            },
        )
    };

    // Return the proposal with the given ID, if one exists
    public query func get_proposal(proposal_id : Nat) : async ?Types.Proposal {
        Debug.print("get_proposal for id: " # debug_show (proposal_id));
        proposal_get(proposal_id)
    };

    // Return the list of all proposals
    public query func get_all_proposals() : async [Types.Proposal] {
        Debug.print("get_all_proposals");
        Iter.toArray(Iter.map(Trie.iter(proposals), func(kv : (Nat, Types.Proposal)) : Types.Proposal = kv.1))
    };

    func proposal_get(id : Nat) : ?Types.Proposal = Trie.get(proposals, Types.proposal_key(id), Nat.equal);
    func proposal_put(id : Nat, proposal : Types.Proposal) {
        proposals := Trie.put(proposals, Types.proposal_key(id), Nat.equal, proposal).0
    };

    // Deduct the proposal submission deposit from the caller's account
    func deduct_proposal_submission_deposit(caller : Principal) : Types.Result<(), Text> {
        Debug.print("deduct_proposal_submission_deposit -> for caller " # debug_show (caller));
        let caller_tokens : ?Types.Tokens = account_get(caller);
        Debug.print("deduct_proposal_submission_deposit from caller. Current balance: " # debug_show (caller_tokens));

        switch (caller_tokens) {
            case null { #err "Caller needs an account to submit a proposal" };
            case (?from_tokens) {
                Debug.print("deduct_proposal_submission_deposit -> from_tokens: " # debug_show (from_tokens));
                let threshold = system_params.proposal_submission_deposit.amount_e8s;
                Debug.print("threshold: " # debug_show (threshold));

                if (from_tokens.amount_e8s < threshold) {
                    Debug.print("Cannler's account doesn't have enough tokens to submit the proposal. Caller has: " # debug_show (from_tokens.amount_e8s));
                    #err("Caller's account must have at least " # debug_show (threshold) # " to submit a proposal. Current balance is: " # debug_show (from_tokens.amount_e8s))
                } else {
                    let from_amount : Nat = from_tokens.amount_e8s - threshold;
                    Debug.print("Caller has enough tokens to create proposal. Tokens deducted. New balance: " # debug_show (from_amount));
                    account_put(caller, { amount_e8s = from_amount });
                    #ok
                }
            }
        }
    };

    // Execute all accepted proposals
    // TODO: This used to be called in a heartbeat, but it would consume too many cycles, so need to think of a better approach.
    // For now, it needs to be called manually via dfx / candid
    // dfx canister call dao execute_accepted_proposals
    public shared ({ caller }) func execute_accepted_proposals() : async () {
        let accepted_proposals = Trie.filter(proposals, func(_ : Nat, proposal : Types.Proposal) : Bool = proposal.state == #accepted);
        Debug.print("execute_accepted_proposals -> accepted_proposals: " # debug_show (accepted_proposals));

        // Update proposal state, so that it won't be picked up by the next heartbeat
        for ((id, proposal) in Trie.iter(accepted_proposals)) {
            update_proposal_state(proposal, #executing)
        };

        for ((id, proposal) in Trie.iter(accepted_proposals)) {
            switch (await execute_proposal(proposal)) {
                case (#ok) { update_proposal_state(proposal, #succeeded) };
                case (#err(err)) {
                    update_proposal_state(proposal, #failed(err))
                }
            }
        }
    };

    // Execute the given proposal
    func execute_proposal(proposal : Types.Proposal) : async Types.Result<(), Text> {
        try {
            let payload = proposal.payload;
            Debug.print("execute_proposal -> proposal to execute: " # debug_show (proposal) # ", payload: " # debug_show (payload));
            ignore await ICRaw.call(payload.canister_id, payload.canister_method, payload.canister_message);
            #ok
        } catch (e) { #err(Error.message e) }
    };

    func update_proposal_state(proposal : Types.Proposal, state : Types.ProposalState) {
        let updated = {
            state;
            id = proposal.id;
            votes_yes = proposal.votes_yes;
            votes_no = proposal.votes_no;
            voters = proposal.voters;
            timestamp = proposal.timestamp;
            proposer = proposal.proposer;
            payload = proposal.payload
        };
        Debug.print("update_proposal_state -> new state: " # debug_show (state) # ", updated proposal: " # debug_show (updated));
        proposal_put(proposal.id, updated)
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      VOTING     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    public shared ({ caller }) func vote2(proposal_id : Int, yes_or_no : Bool) : async Types.Result<(Nat, Nat), Text> {
        Debug.print("vote -> proposal_id: " # debug_show (proposal_id) # ", vote: " # debug_show (yes_or_no) # ", caller: " # debug_show (caller));

        if (Principal.isAnonymous(caller)) {
            return #err("Anonymous callers cannot vote on proposals.")
        };

        let neuron = neurons.get(caller);
        var voting_power : Float = 0;

        // get MB token balance then vote.
        return #err("Not implemented yet")
    };

    // Vote on an open proposal
    public shared ({ caller }) func vote(args : Types.VoteArgs) : async Types.Result<Types.ProposalState, Text> {
        Debug.print("vote -> args: " # debug_show (args) # ", caller: " # debug_show (caller));

        switch (proposal_get(args.proposal_id)) {
            case null {
                #err("No proposal with ID " # debug_show (args.proposal_id) # " exists")
            };
            case (?proposal) {
                var state = proposal.state;
                Debug.print("proposal found -> state: " # debug_show (state));

                if (state != #open) {
                    return #err("Proposal " # debug_show (args.proposal_id) # " is not open for voting")
                };

                switch (account_get(caller)) {
                    case null {
                        return #err("The caller with principal '" # debug_show (caller) # "' does not have any tokens to vote with.")
                    };
                    case (?{ amount_e8s = voting_tokens }) {
                        if (List.some(proposal.voters, func(e : Principal) : Bool = e == caller)) {
                            return #err("The caller with principal '" # debug_show (caller) # "' has already voted.")
                        };

                        var votes_yes = proposal.votes_yes.amount_e8s;
                        var votes_no = proposal.votes_no.amount_e8s;

                        switch (args.vote) {
                            case (#yes) { votes_yes += voting_tokens };
                            case (#no) { votes_no += voting_tokens }
                        };
                        
                        let voters = List.push(caller, proposal.voters);

                        if (votes_yes >= system_params.proposal_vote_threshold.amount_e8s) {
                            // Refund the proposal deposit when the proposal is accepted
                            ignore do ? {
                                let account = account_get(proposal.proposer)!;
                                let refunded = account.amount_e8s + system_params.proposal_submission_deposit.amount_e8s;
                                account_put(proposal.proposer, { amount_e8s = refunded })
                            };
                            state := #accepted
                        };

                        if (votes_no >= system_params.proposal_vote_threshold.amount_e8s) {
                            state := #rejected
                        };

                        let updated_proposal = {
                            id = proposal.id;
                            votes_yes = { amount_e8s = votes_yes };
                            votes_no = { amount_e8s = votes_no };
                            voters;
                            state;
                            timestamp = proposal.timestamp;
                            proposer = proposal.proposer;
                            payload = proposal.payload
                        };
                        proposal_put(args.proposal_id, updated_proposal)
                    }
                };
                #ok(state)
            }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     ACCOUNTS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    func account_get(id : Principal) : ?Types.Tokens = Trie.get(accounts, Types.account_key(id), Principal.equal);
    func account_put(id : Principal, tokens : Types.Tokens) {
        accounts := Trie.put(accounts, Types.account_key(id), Principal.equal, tokens).0
    };
    // Return the list of all accounts
    public query func list_accounts() : async [Types.Account] {
        Debug.print("get_all_accounts");
        Iter.toArray(
            Iter.map(
                Trie.iter(accounts),
                func((owner : Principal, tokens : Types.Tokens)) : Types.Account = {
                    owner;
                    tokens
                },
            ),
        )
    };

    // Return the account balance of the caller
    public query ({ caller }) func account_balance() : async Types.Tokens {
        Debug.print("account_balance -> caller: " # debug_show (caller));
        Option.get(account_get(caller), Types.zeroToken)
    };

    // Transfer tokens from the caller's account to another account
    public shared ({ caller }) func transfer(transfer : Types.TransferArgs) : async Types.Result<(), Text> {
        Debug.print("transfer -> transfer: " # debug_show (transfer) # ", caller: " # debug_show (caller));
        switch (account_get caller) {
            case null {
                #err "The caller needs an account to transfer funds. Please authenticate via a wallet plugin and try again."
            };
            case (?from_tokens) {
                let fee = system_params.transfer_fee.amount_e8s;
                let amount = transfer.amount.amount_e8s;
                Debug.print("fee: " # debug_show (fee) # ", transfer amount: " # debug_show (amount) # ", caller balance: " # debug_show(from_tokens.amount_e8s));

                if (from_tokens.amount_e8s < amount + fee) {
                    #err("The caller's with principal '" # debug_show (caller) # "' does not have enough tokens to transfer " # debug_show (amount))
                } else {
                    let from_amount : Nat = from_tokens.amount_e8s - amount - fee;
                    account_put(caller, { amount_e8s = from_amount });
                    let to_amount = Option.get(account_get(transfer.to), Types.zeroToken).amount_e8s + amount;
                    account_put(transfer.to, { amount_e8s = to_amount });
                    #ok
                }
            }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    BOOTSTRAP    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // dfx canister call dao bootstrap_accounts '(vec { record { owner = principal \"$ALICE\"; tokens = record { amount_e8s = 100_000_000 }; }; record { owner = principal \"$BOB\"; tokens = record { amount_e8s = 100_000_000 };}; };)'
    // dfx canister call dao bootstrap_accounts '(opt vec {record {owner=principal "2vxsx-fae"; tokens=record {amount_e8s=500000}}; record {owner=principal "jxic7-kzwkr-4kcyk-2yql7-uqsrg-lvrzb-k7avx-e4nbh-nfmli-rddvs-mqe"; tokens=record {amount_e8s=300000}}; record {owner=principal "7kr6j-mbzim-ly6wk-gzwcx-3gkbo-jc4ur-goa5r-we57n-sbwje-aof3q-kae"; tokens=record {amount_e8s=200000}}; record {owner=principal "lqvzl-mjmrn-xeyre-6vgws-copfr-axrrb-pvwka-awx3d-h5bls-mpwys-kqe"; tokens=record {amount_e8s=100000}}})'
    public func bootstrap_accounts(bootstrap : ?[Types.Account]) : async () {
        accounts := Types.accounts_fromArray(switch (bootstrap) { case null { null }; case (?i) { ?i } })
    };

    // dfx canister call dao bootstrap_proposals '(opt vec {record {id=1; votes_no=record {amount_e8s=0}; voters=opt record {principal "jxic7-kzwkr-4kcyk-2yql7-uqsrg-lvrzb-k7avx-e4nbh-nfmli-rddvs-mqe"; null}; state=variant {open}; timestamp=1674287003083988472; proposer=principal "bi3lr-cwsga-wc4qg-ypqug-mkn4l-2l436-yxpkm-dozec-ah3nq-qmjqo-lae"; votes_yes=record {amount_e8s=10000}; payload=record {canister_message=vec {85; 112; 100; 97; 116; 101; 100; 32; 112; 97; 103; 101; 32; 116; 105; 116; 108; 101}; canister_id=principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; proposal_summary="Update page_title to "Updated page title""; canister_method="update_page_title"}}})'
    public func bootstrap_proposals(bootstrap : ?[Types.Proposal]) : async () {
        proposals := Types.proposals_fromArray(switch (init) { case null { null }; case (?i) { ?i.proposals } })
    };

    // dfx canister call dao bootstrap_system_params '(record {transfer_fee = record { amount_e8s = 10_000 }; proposal_vote_threshold = record { amount_e8s = 10_000_000 }; proposal_submission_deposit = record { amount_e8s = 10_000 }; };)'
    public func bootstrap_system_params(bootstrap : ?Types.SystemParams) : async () {
        system_params := switch (init) {
            case null { Types.defaulSystemParams };
            case (?i) { i.system_params }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      SYSTEM     MANAGEMENT   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/heartbeats
    // Called on every Internet Computer subnet heartbeat, by scheduling an asynchronous call to the heartbeat function.
    // Due to its async return type, a heartbeat function may send further messages and await results.
    // The result of a heartbeat call, including any trap or thrown error, is ignored.
    // The implicit context switch inherent to calling every Motoko async function, means that the time the heartbeat body is executed may be later than the time the heartbeat was issued by the subnet.
    // There are issues around hearbeat cycle burn rate (https://forum.dfinity.org/t/cycle-burn-rate-heartbeat/12090), so we won't be enabling this.
    system func heartbeat() : async () {
        let timestamp = Time.now();
        // Debug.print("heartbeat - timestamp: " # debug_show(timestamp));
        // await execute_accepted_proposals()
    };

    // Get the current system params
    public query func get_system_params() : async Types.SystemParams {
        system_params
    };

    // Update system params
    public shared ({ caller }) func update_system_params(payload : Types.UpdateSystemParamsPayload) : async () {
        // Only callable via proposal execution by this actor itself
        if (caller != Principal.fromActor(Self)) {
            return
        };

        system_params := {
            transfer_fee = Option.get(payload.transfer_fee, system_params.transfer_fee);
            proposal_vote_threshold = Option.get(payload.proposal_vote_threshold, system_params.proposal_vote_threshold);
            proposal_submission_deposit = Option.get(payload.proposal_submission_deposit, system_params.proposal_submission_deposit)
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      UPGARDE    MANAGEMENT   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    system func preupgrade() {
        // proposals := Buffer.toArray(proposal_buff)
    };

    system func postupgrade() {
        // proposals := Buffer.toArray(proposal_buff)
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       JUST      EXPERIMENTS  ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    type Trie<K, V> = Trie.Trie<K, V>;
    type Key<K> = Trie.Key<K>;
    func key(t : Text) : Key<Text> { { key = t; hash = Text.hash t } };

    // (variant {leaf=record {size=2; keyvals=opt record {record {record {key="hello"; hash=261238937}; 42}; opt record {record {record {key="world"; hash=279393645}; 24}; null}}}})
    // (variant {
    //     leaf=record {
    //         size=2; keyvals=opt record {
    //             record {record {key="hello"; hash=261238937}; 42};
    //             opt record {record {record {key="world"; hash=279393645}; 24}; null}
    //         }
    //     }
    // })
    public query func tries() : async Trie.Trie<Text, Nat> {
        let t0 : Trie<Text, Nat> = Trie.empty();
        let t1 : Trie<Text, Nat> = Trie.put(t0, key "hello", Text.equal, 42).0;
        let t2 : Trie<Text, Nat> = Trie.put(t1, key "world", Text.equal, 24).0;
        let n : ?Nat = Trie.put(t1, key "hello", Text.equal, 0).1;
        assert (n == ?42);
        return t2
    }
}
