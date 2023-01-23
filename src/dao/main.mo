import Char "mo:base/Char";
import Text "mo:base/Text";
import Map "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import List "mo:base/List";
import Time "mo:base/Time";
import Types "./Types";
import Debug "mo:base/Debug";

// DAO actor class with the capability to accept init bootstrap data.
// The init has been made optional, so that we can deploy without bootstrapping as well.
shared ({ caller = creator }) actor class DAO(init : ?Types.BasicDaoStableStorage) = Self {
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       SETUP     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    stable var admins : [Principal] = [creator];
    public type Proposal = Types.Proposal;
    // Store the accounts, neurons, proposals and system parameters in stable memory.
    let Faucet : actor { 
        icrc1_balance_of : ({owner: Principal; subaccount: ?[Nat8]}) -> async Nat;
        icrc1_transfer : ({
            to: {owner: Principal; subaccount: ?[Nat8]}; fee: ?Nat; memo: ?[Nat8];
            from_subaccount: ?[Nat8]; created_at_time: ?Nat64; amount: Nat
          }) -> async ({
            #ok: [Nat];
            #err: {
              #GenericError: {message:Text; error_code:Nat}; 
              #TemporarilyUnavailable; 
              #BadBurn: {min_burn_amount: Nat}; 
              #Duplicate: {duplicate_of: Nat}; 
              #BadFee: {expected_fee: Nat}; 
              #CreatedInFuture: {ledger_time: Nat64}; 
              #TooOld; 
              #InsufficientFunds: {balance: Nat}
            }
        })
    } = actor ("db3eq-6iaaa-aaaah-abz6a-cai");
    // let webpage_canister_id = "ryjl3-tyaaa-aaaaa-aaaba-cai"; // Local
    let webpage_canister_id = "6pabh-miaaa-aaaap-qa5nq-cai"; // Network
    let Webpage : actor { 
        update_page_title : ({title: Text}) -> async Text;
        update_page_content : ({content: Text}) -> async Text;
    } = actor (webpage_canister_id);
    stable var accounts = Types.accounts_fromArray(switch (init) { case null { null }; case (?i) { ?i.accounts } });
    stable var neuron_entries : [(Principal, Types.Neurons)] = [];
    stable var proposals = Types.proposals_fromArray(switch (init) { case null { null }; case (?i) { ?i.proposals } });
    stable var next_proposal_id : Nat = 0;
    stable var system_params : Types.SystemParams = switch (init) {
        case null { Types.defaulSystemParams };
        case (?i) { i.system_params }
    };
    // Create an in-memory array of neurons so we can work with them easier during canister operation. These will be saved to stable memory during upgrades.
    let neurons = HashMap.fromIter<Principal, Types.Neurons>(neuron_entries.vals(), Iter.size(neuron_entries.vals()), Principal.equal, Principal.hash);

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:     ACCOUNTS    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Get the account for the specified principal.
    func account_get(id : Principal) : ?Types.Tokens = Trie.get(accounts, Types.account_key(id), Principal.equal);

    // Update the account for the specified principal.
    func account_put(id : Principal, tokens : Types.Tokens) {
        accounts := Trie.put(accounts, Types.account_key(id), Principal.equal, tokens).0
    };

    // Return the list of all accounts.
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

    // Get user's MBT tokens
    // dfx canister call dao get_mbt_tokens '(principal "jos7q-ggkck-prpv7-sizou-k7pvy-dnsra-oojo2-k25j4-44z5d-zi7ca-eae")'
    // https://m7sm4-2iaaa-aaaab-qabra-cai.raw.ic0.app/?tag=3939871666
    public shared ({ caller }) func get_mbt_tokens() : async Nat { //, s : ?[Nat8]
        Debug.print("getMBTTokens -> caller: " # debug_show (caller)); // # ", account: " # debug_show(account) # ", subaccount: " # debug_show(s)
        let response = await Faucet.icrc1_balance_of({owner = caller; subaccount = null});
        return response;
    };

    // Transfer MBT tokens
    public shared ({ caller }) func transfer_mbt_tokens(from: Principal, to: Principal, amount: Nat) : async Text {
        Debug.print("transferMBTTokens -> caller: " # debug_show (caller) # ", from: " # debug_show(from) # ", to: " # debug_show(to) # ", amount: " # debug_show(amount));
        let response = await Faucet.icrc1_transfer(
        {
            to = {owner = to; subaccount = null}; 
            fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount
        }
        );

        switch (response) {
            case (#ok(unwrapped_val)) "The transaction was successfu. TxID: " # debug_show(unwrapped_val);
            case (#err(unwrapped_val)) {
                switch (unwrapped_val) {
                    case (#GenericError(details)) "An error occurred. ErrorCode: " # debug_show(details.error_code) # ", Message: " # debug_show(details.message);
                    case (#TemporarilyUnavailable) "The service is temporarily unavaialble.";
                    case (#BadBurn(details)) "The transfer amount needs to be greater than the transfer fee. Minimum burn amount: " # debug_show(details.min_burn_amount);
                    case (#Duplicate(details)) "This transaction is a duplicate of TxID: " # debug_show(details.duplicate_of);
                    case (#BadFee(details)) "The fee provided couldn't be accepted. Expected fee: " # debug_show(details.expected_fee);
                    case (#CreatedInFuture(details)) "The transaction seems to have been created in the future and cannot be processed right now. Timestamp: " # debug_show(details.ledger_time);
                    case (#TooOld) "The transaction is too old to process";
                    case (#InsufficientFunds(details)) "The transfer amount is greater than the available balance. Available balance: " # debug_show(details.balance);
                };
            };
        };
    };

    // Return the caller's stake (balance, neurons)
    public shared ({ caller }) func get_staked_tokens() : async Types.Result<Types.StakedBalance, Text> {
        Debug.print("get_staked_tokens -> caller: " # debug_show (caller));
        var staked_balance = Option.get(account_get(caller), Types.zeroToken);
        var staked_neurons = Option.get(neurons.get(caller), []);
        let fee = system_params.transfer_fee.amount_e8s;
        var message : Text = "The current fee for staking tokens is: " # debug_show(fee) # " MBT.\n";
        Debug.print("fee: " # debug_show (fee) # ", staked amount (caller balance): " # debug_show (staked_balance) # ", staked neurons: " # debug_show(staked_neurons));           

        #ok(Types.prepare_staked_balance_response(staked_balance, staked_neurons, message));
    };

    // Stake tokens from the caller's account and generate neurons
    public shared ({ caller }) func stake(stake : Types.StakeArgs) : async Types.Result<Text, Text> {
        let account = Option.get(account_get(caller), Types.zeroToken);
        let stake_amount : Nat = stake.amount.amount_e8s;
        let stake_duration : Nat = stake.duration;
        let duration_desc : Text = getStakingDurationDesc(stake.duration);
        Debug.print("stake -> stake payload: " # debug_show (stake) # ", caller: " # debug_show (caller) # ", current stake balance: " # debug_show(account.amount_e8s));
        var account_balance : Nat = account.amount_e8s + stake.amount.amount_e8s;
        var account_neurons : Types.Neurons = Option.get(neurons.get(caller), []);
        var account_neurons_mutable = Array.thaw<Types.Neuron>(account_neurons);

        // Set the new stake balance on the account.
        account_put(caller, { amount_e8s = account_balance });

        // Create the neurons.
        let neuron : Types.Neuron = {
            owner = caller;
            amount = stake_amount;
            dissolveDelay = stake_duration;
            neuronState = #Locked;
            createdAt = Time.now();
            dissolvedAt = 0;
        };
        account_neurons_mutable[account_neurons_mutable.size()] := neuron;
        neurons.put(caller, Array.freeze<Types.Neuron>(account_neurons_mutable));
        
        #ok("Congratulations! You have successfully staked " # debug_show(stake_amount) # " " # Types.token_desc # ". Your total staked amount is " # debug_show(account_balance) # Types.token_desc # ".");
    };

    // Transfer tokens from the caller's account to another account
    public shared ({ caller }) func transfer(transfer : Types.TransferArgs) : async Types.Result<(), Text> {
        Debug.print("transfer -> transfer: " # debug_show (transfer) # ", caller: " # debug_show (caller));
        switch (account_get(caller)) {
            case null {
                #err "The caller needs an account to transfer funds. Please authenticate via a wallet plugin and try again."
            };
            case (?staked_balance) {
                let fee = system_params.transfer_fee.amount_e8s;
                let amount = transfer.amount.amount_e8s;
                Debug.print("fee: " # debug_show (fee) # ", transfer amount: " # debug_show (amount) # ", caller balance: " # debug_show(staked_balance.amount_e8s));

                if (staked_balance.amount_e8s < amount + fee) {
                    #err("The caller's with principal '" # debug_show (caller) # "' does not have enough tokens to transfer " # debug_show (amount))
                } else {
                    let from_amount : Nat = staked_balance.amount_e8s - amount - fee;
                    account_put(caller, { amount_e8s = from_amount });
                    let to_amount = Option.get(account_get(transfer.to), Types.zeroToken).amount_e8s + amount;
                    account_put(transfer.to, { amount_e8s = to_amount });
                    #ok
                }
            }
        }
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
            case null { #err "Caller needs an account and have staked MBT to submit a proposal" };
            case (?staked_balance) {
                Debug.print("deduct_proposal_submission_deposit -> staked_balance: " # debug_show (staked_balance));
                let threshold = system_params.proposal_submission_deposit.amount_e8s;
                Debug.print("threshold: " # debug_show (threshold));

                if (staked_balance.amount_e8s < threshold) {
                    Debug.print("Cannler's account doesn't have enough tokens to submit the proposal. Caller has: " # debug_show (staked_balance.amount_e8s));
                    #err("Caller's account must have at least " # debug_show (threshold) # " to submit a proposal. Current balance is: " # debug_show (staked_balance.amount_e8s))
                } else {
                    let from_amount : Nat = staked_balance.amount_e8s - threshold;
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

    // Admin only function for local testing. Should never be enabled in production.
    public shared ({ caller }) func execute_selected_proposal(proposalID: Nat) : async () {
        // assert(is_admin(caller));
        Debug.print("execute_selected_proposal (ADMIN ONLY) -> proposal to execute: " # debug_show (proposalID));

        switch (proposal_get(proposalID)) {
            case (null) {};
            case (?proposal) { ignore await execute_proposal(proposal); };
        };
    };

    // Execute the given proposal
    func execute_proposal(proposal : Types.Proposal) : async Types.Result<(), Text> {
        try {
            let payload = proposal.payload;
            Debug.print("execute_proposal -> proposal to execute: " # debug_show (proposal) # ", payload: " # debug_show (payload));
            // ignore await ICRaw.call(payload.canister_id, payload.canister_method, payload.canister_message);
            Debug.print("payload.canister_id: " # debug_show (payload.canister_id) # ", dao_canister_id: " # debug_show (getMyPrincipal()));

            if (payload.canister_id == getMyPrincipal()) {
                let newValue : Nat = textToNat(Option.get(Text.decodeUtf8(payload.canister_message), ""));
                let newValueAsTokens : ?Types.Tokens = ?{ amount_e8s = newValue };
                Debug.print("Updating DAO canister system parameters - updating: " # debug_show (payload.canister_method) # ", new value: " # debug_show (newValue));

                if (payload.canister_method == "transfer_fee") {
                    let res = await update_system_params({
                        transfer_fee = newValueAsTokens;
                        proposal_vote_threshold = ?system_params.proposal_vote_threshold;
                        proposal_submission_deposit = ?system_params.proposal_submission_deposit
                    });
                    Debug.print("Response for " # debug_show(payload.canister_method) # " - " # debug_show(res));
                } else if (payload.canister_method == "proposal_vote_threshold") {
                    let res = await update_system_params({
                        transfer_fee = ?system_params.transfer_fee;
                        proposal_vote_threshold = newValueAsTokens;
                        proposal_submission_deposit = ?system_params.proposal_submission_deposit
                    }); 
                    Debug.print("Response for " # debug_show(payload.canister_method) # " - " # debug_show(res));
                } else if (payload.canister_method == "proposal_submission_deposit") {
                    let res = await update_system_params({
                        transfer_fee = ?system_params.transfer_fee;
                        proposal_vote_threshold = ?system_params.proposal_vote_threshold;
                        proposal_submission_deposit = newValueAsTokens
                    }); 
                    Debug.print("Response for " # debug_show(payload.canister_method) # " - " # debug_show(res));
                } else {
                    Debug.print("Should not be coming into here."); 
                    return #err("Unsupported execution for the DAO canister proposal execution.")
                };
            } else {
                let newValue : Text = Option.get(Text.decodeUtf8(payload.canister_message), "");
                Debug.print("Updating Webpage canister content - updating: " # debug_show (payload.canister_method) # ", new value: " # debug_show (newValue));
                
                if (payload.canister_method == "update_page_title") {
                    let res = await Webpage.update_page_title({title = newValue}); 
                    Debug.print("Response for " # debug_show(payload.canister_method) # " - " # debug_show(res));
                } else if (payload.canister_method == "update_page_content") {
                    let res = await Webpage.update_page_content({content = newValue}); 
                    Debug.print("Response for " # debug_show(payload.canister_method) # " - " # debug_show(res));
                } else {
                    Debug.print("Should not be coming into here."); 
                    return #err("Unsupported execution for the Webpage canister proposal execution.")
                };
            };

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

    // Vote on an open proposal
    public shared ({ caller }) func vote(args : Types.VoteArgs) : async Types.Result<Text, Text> {
        Debug.print("vote -> args: " # debug_show (args) # ", caller: " # debug_show (caller));

        // Commented out for testing purposes
        // if (Principal.isAnonymous(caller)) {
            // return #err("Anonymous callers cannot vote on proposals.")
        // };

        // TODO: Neurons and voting power.
        let neuron = neurons.get(caller);
        var voting_power : Float = 0;
        
        // Since we're not executing this in the heartbeat, we'll execute it everytime someone attempts to vote.
        await execute_accepted_proposals();

        switch (proposal_get(args.proposal_id)) {
            case null {
                let message = "No proposal with ID " # debug_show (args.proposal_id) # " exists";
                Debug.print(message);
                #err(message)
            };
            case (?proposal) {
                var state = proposal.state;
                Debug.print("proposal found -> state: " # debug_show (state));

                if (state != #open) {
                    let message = "Proposal " # debug_show (args.proposal_id) # " is not open for voting";
                    Debug.print(message);
                    return #err(message)
                };

                switch (account_get(caller)) {
                    case null {
                        let message = "The caller with principal '" # debug_show (caller) # "' does not have any staked tokens to vote with.";
                        Debug.print(message);
                        return #err(message)
                    };
                    case (?{ amount_e8s = voting_tokens }) {
                        if (List.some(proposal.voters, func(e : Principal) : Bool = e == caller)) {
                            let message = "The caller with principal '" # debug_show (caller) # "' has already voted.";
                            Debug.print(message);
                            return #err(message)
                        };

                        var votes_yes = proposal.votes_yes.amount_e8s;
                        var votes_no = proposal.votes_no.amount_e8s;
                        Debug.print("Caller's vote value will be: " # debug_show(voting_tokens));

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

                #ok("")
            }
        }
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      UTILITY    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Get the staking duration as a string
    func getStakingDurationDesc(duration: Nat) : Text {
        switch (duration) {
            case 6 { "6 Months" };
            case 12 { "1 Year" };
            case 24 { "2 Years" };
            case 36 { "3 Years" };
            case 48 { "4 Years" };
            case 60 { "5 Years" };
            case 72 { "6 Years" };
            case 84 { "7 Years" };
            case 96 { "8 Years" };
            case _ { "Undefined Period (" # debug_show(duration) # ")" };
        }
    };

    // Convert text to Nat
    // Credits: goose
    // Ref: https://forum.dfinity.org/t/motoko-convert-text-123-to-nat-or-int-123/7033/2?u=amircx
    func textToNat( txt : Text) : Nat {
        assert(txt.size() > 0);
        let chars = txt.chars();
        var num : Nat = 0;

        for (v in chars){
            let charToNum = Nat32.toNat(Char.toNat32(v)-48);
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  charToNum;          
        };

        num;
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:    BOOTSTRAP    ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // dfx canister call dao bootstrap_accounts '(vec { record { owner = principal \"$ALICE\"; tokens = record { amount_e8s = 100_000 }; }; record { owner = principal \"$BOB\"; tokens = record { amount_e8s = 100_000 };}; };)'
    // dfx canister call dao bootstrap_accounts '(opt vec {record {owner=principal "2vxsx-fae"; tokens=record {amount_e8s=500000}}; record {owner=principal "jxic7-kzwkr-4kcyk-2yql7-uqsrg-lvrzb-k7avx-e4nbh-nfmli-rddvs-mqe"; tokens=record {amount_e8s=300000}}; record {owner=principal "7kr6j-mbzim-ly6wk-gzwcx-3gkbo-jc4ur-goa5r-we57n-sbwje-aof3q-kae"; tokens=record {amount_e8s=200000}}; record {owner=principal "lqvzl-mjmrn-xeyre-6vgws-copfr-axrrb-pvwka-awx3d-h5bls-mpwys-kqe"; tokens=record {amount_e8s=100000}}})'
    public func bootstrap_accounts(bootstrap : ?[Types.Account]) : async () {
        accounts := Types.accounts_fromArray(switch (bootstrap) { case null { null }; case (?i) { ?i } })
    };

    // dfx canister call dao bootstrap_proposals '(opt vec {record {id=1; votes_no=record {amount_e8s=0}; voters=opt record {principal "jxic7-kzwkr-4kcyk-2yql7-uqsrg-lvrzb-k7avx-e4nbh-nfmli-rddvs-mqe"; null}; state=variant {open}; timestamp=1674287003083988472; proposer=principal "bi3lr-cwsga-wc4qg-ypqug-mkn4l-2l436-yxpkm-dozec-ah3nq-qmjqo-lae"; votes_yes=record {amount_e8s=10000}; payload=record {canister_message=vec {85; 112; 100; 97; 116; 101; 100; 32; 112; 97; 103; 101; 32; 116; 105; 116; 108; 101}; canister_id=principal "6pabh-miaaa-aaaap-qa5nq-cai"; proposal_summary="Update page_title to "Updated page title""; canister_method="update_page_title"}}})'
    public func bootstrap_proposals(bootstrap : ?[Types.Proposal]) : async () {
        proposals := Types.proposals_fromArray(switch (init) { case null { null }; case (?i) { ?i.proposals } })
    };

    // dfx canister call dao bootstrap_system_params '(record {transfer_fee = record { amount_e8s = 10_000 }; proposal_vote_threshold = record { amount_e8s = 100_000 }; proposal_submission_deposit = record { amount_e8s = 10_000 }; };)'
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
    /*system func heartbeat() : async () {
        let timestamp = Time.now();
        // Debug.print("heartbeat - timestamp: " # debug_show(timestamp));
        // await execute_accepted_proposals()
    };*/

    // Get the current system params
    public query func get_system_params() : async Types.SystemParams {
        system_params
    };

    func getMyPrincipal() : Principal {
        return Principal.fromActor(Self);
    };

    // Update system params
    public shared ({ caller }) func update_system_params(payload : Types.UpdateSystemParamsPayload) : async () {
        // Only callable via proposal execution by this actor itself
        if (caller != getMyPrincipal()) {
            return
        };

        system_params := {
            transfer_fee = Option.get(payload.transfer_fee, system_params.transfer_fee);
            proposal_vote_threshold = Option.get(payload.proposal_vote_threshold, system_params.proposal_vote_threshold);
            proposal_submission_deposit = Option.get(payload.proposal_submission_deposit, system_params.proposal_submission_deposit)
        }
    };

    // Get the cycles balance
    public query func cycle_balance() : async Nat {
        let balance = Cycles.balance();
        Debug.print("Cycles balance: " # debug_show(balance));
        return balance;
    };

    // Receive cycles
    public shared ({ caller }) func receive_cycles() : async Result.Result<Text, Text> {
        let cycles = Cycles.available();
        Debug.print("Received and accepted cycles: " # debug_show(cycles));
        ignore Cycles.accept(cycles);
        return #ok("Thanks!.")
    };

    public shared ({ caller }) func send_cycles (principalID : Text) : async Result.Result<Text, Text> {
        Debug.print("Current balance: " # Nat.toText(Cycles.balance()));
        let recipient : actor {  receive_cycles : () -> async Result.Result<Text, Text>; } = actor(principalID);
        Cycles.add(1_000_000_100);
        let send = await recipient.receive_cycles();
        Debug.print("Unused balance: " # Nat.toText(Cycles.refunded()));
        send
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:      UPGARDE    MANAGEMENT   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    // Make a final update to stable variables, before the runtime commits their values to Internet Computer stable memory, and performs an upgrade.
    // So, here we want to take our values that are in our HashMap (and not stable) and put them into the stable array instead.
    // Ref: https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/upgrades#preupgrade-and-postupgrade-system-methods
    system func preupgrade() {
        neuron_entries := Iter.toArray(neurons.entries());
    };

    // Runs after an upgrade has initialized the replacement actor, including its stable variables, but before executing any shared function call (or message) on that actor.
    // Here, we want to reset the stable var, as we'll be storing the data to be used in our HashMap.
    system func postupgrade() {
        neuron_entries := [];
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       ADMIN     ----------   ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    func is_admin (principal : Principal,) : Bool {
        switch (Array.find<Principal>(admins, func (x) { x == principal })) {
            case (?a) true;
            case _ false;
        };
    };

    public shared func get_admins () : async [Principal] {
        admins;
    };

    public shared ({ caller }) func remove_admins (removals : [Principal]) : async () {
        Debug.print("remove_admins called by " # debug_show(caller));
        assert(is_admin(caller));
        admins := Array.filter<Principal>(admins, func (admin) {
            Option.isNull(Array.find<Principal>(removals, func (x) { x == admin }));
        });
    };

    public shared ({ caller }) func addAdmins (newAdmins : [Principal]) : async () {
        Debug.print("addAdmins called by " # debug_show(caller));
        assert(is_admin(caller));
        admins := Array.append(admins, Array.filter<Principal>(newAdmins, func (x) {
            Option.isNull(Array.find<Principal>(admins, func (y) { x == y }));
        }));
    };

    public shared ({ caller }) func admin_function () : async Text {
        Debug.print("admin_function called by " # debug_show(caller));
        assert(is_admin(caller));
        "Hello, admin!";
    };

    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
    //  REGION:       JUST      EXPERIMENTS  ----------   ----------   ----------   ----------   ----------
    //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

    /*type Trie<K, V> = Trie.Trie<K, V>;
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
    }*/
}
