<script>
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import { proposalToVote } from "../stores.js"
  import { hasVoted } from "../stores.js"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { get } from "svelte/store"
  import { daoActor, principal, daoCanisterId, webpageCanisterId, voteTokens, proposalVoteThreshold } from "../stores"
  import { decodeUtf8, getFormattedToken, getAllProposals } from "../lib.js"
  import { idlFactory } from "../../src/declarations/dao"

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:   DEFINITIONS   ----------   ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  let chosenProposal = ""
  // let chosenVote = ""
  // let voteId = ""
  // let id = ""

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:    PROPOSALS     RELATED     ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  let allProposalsPromise = getAllProposals(get(daoActor));

  /*let getProposalPromise
  async function get_proposal(thisID) {
    let dao = get(daoActor)

    if (!dao) {
      return
    }

    let res

    try {
      res = await dao.get_proposal(BigInt(thisID))
    } catch (error) {
      console.log("Error getting proposal", thisID, error)
      throw new Error(error)
    }

    if (res.length !== 0) {
      return res[0]
    } else {
      throw new Error(
        "Could not find this proposal, make sure you typed in the right ID",
      )
    }
  }

  function handleProposalCheck(payload) {
    console.log("EVENT --- handleProposalCheck", payload)
    id = payload
    getProposalPromise = get_proposal(id)
  }

  //I assume the vote Yes/No will be represented as True/False
  function setProposal(x) {
    console.log("EVENT --- setProposal", x)
    $proposalToVote.proposalID = x

    if (x != "null") {
      handleProposalCheck(x)
    }
  }*/

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:       VOTES      RELATED     ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  async function vote(proposalID, votePayload) {
    let dao = get(daoActor)
    let res

    if (!dao) {
      return
    }

    // Thans Ori for describing how to pass in variants from the JS front-end.
    // Ref: https://forum.dfinity.org/t/can-i-call-a-canister-function-that-have-a-variant-as-a-parameter-how/6745/3
    let voteVariant = votePayload ? { yes: null } : { no: null }
    let payload = (idlFactory.Record = {
      vote: voteVariant,
      proposal_id: proposalID
    })

    await dao
      .vote(payload)
      .then((response) => {
        if (response.ok) {
          return response.ok
        } else {
          throw new Error(response.err)
        }
      })
      .catch((error) => {
        console.log("Error voting - ", proposalID, votePayload, error)
        throw new Error(error)
      })
  }

  let votePromise

  function handleVoteClick(votePayload) {
    console.log("EVENT --- handleVoteClick - vote: ", votePayload, ", chosenProposal: ", chosenProposal)
    votePromise = vote(chosenProposal, votePayload)
    $hasVoted = true
  }

  onMount(async () => {
    // console.log("Vote -> onMount")
    allProposalsPromise = getAllProposals(get(daoActor));
    // console.log("Vote - allProposalsPromise - ", allProposalsPromise);
    // console.log("proposalOptions - ", proposalOptions);
  })

  beforeUpdate(() => {
    // console.log("Vote -> beforeUpdate")
  })

  afterUpdate(() => {
    // console.log("Vote -> afterUpdate")
  })
</script>

<div class="votemain">
  {#if $principal}
    {#if !Number.isInteger(chosenProposal)}
      <img src={mot} class="bg" alt="logo" />
    {/if}
    {#await allProposalsPromise}
      <h2 class="slogan">Loading...</h2>
    {:then proposalOptions}
      { (console.log("Vote - proposal options within view block: ", proposalOptions), '') }
      <h1 class="slogan">Please select a proposal!</h1>
      <div class="form-buttons">
        <select name="chosenProposal" bind:value={chosenProposal} on:change={() => hasVoted.set(false)} style="display:100%"> <!-- on:change={() => setProposal(chosenProposal)} -->
          {#each proposalOptions as option}
            <option value={Number.parseInt(option.id)}>
              [{option.id}]
              { (option.payload.canister_id === daoCanisterId ? " [DAO Canister] " : " [Webpage Canister] ") }
              [{ option.payload.canister_method }]
              {option.payload.proposal_summary}
            </option>
          {/each}
        </select>
      </div>
      { (console.log("Vote - chosen proposal within view block: ", chosenProposal), '') }

      {#if Number.isInteger(chosenProposal)}
        <div class="post-preview">
          <h2>[{proposalOptions[chosenProposal].id}] {proposalOptions[chosenProposal].payload.proposal_summary}</h2>
          <p>Created: {new Date(Number.parseInt(proposalOptions[chosenProposal].timestamp / BigInt(1000000)))}</p>
          <p>State: {Object.keys(proposalOptions[chosenProposal].state)[0]}</p>
          <p>Proposer: {proposalOptions[chosenProposal].proposer.toString()}</p>
      
          <h2>Payload Details</h2>
          <p>Canister ID: {proposalOptions[chosenProposal].payload.canister_id}</p>
          <p>Canister Method: {proposalOptions[chosenProposal].payload.canister_method}</p>
          <p>Canister Message: {decodeUtf8(proposalOptions[chosenProposal].payload.canister_message)}</p>
      
          <h2>Vote Statistics</h2>
          <p>
            Yes: {getFormattedToken(BigInt(proposalOptions[chosenProposal].votes_yes.amount_e8s / BigInt(100000000)))}, 
            No: {getFormattedToken(BigInt(proposalOptions[chosenProposal].votes_no.amount_e8s / BigInt(100000000)))}
          </p>
          <p>Vote Pass Threshold: {getFormattedToken($proposalVoteThreshold)}</p>
          <p>Voting requires you to have {getFormattedToken($voteTokens)} staked with the DAO.</p>

          <div class="form-buttons">
            <button class="vote-button" on:click={() => handleVoteClick(true)}>Yes</button>
            <button class="vote-button" on:click={() => handleVoteClick(false)}>No</button>
          </div>

          {#if $hasVoted === true}
            {#await votePromise}
              <h1 class="slogan black">Loading...</h1>
            {:then voteResult}
              <h3 class="slogan" style="color: black;">
                Voted successfully! {voteResult}
              </h3>
            {:catch error}
              { (($hasVoted = false), '') }
              <p style="color: red">{error.message}</p>
            {/await}
          {/if}
          
        </div>
      {/if}
    {:catch error}
      <h1 class="slogan">Please input a proposal ID!</h1>
      <input bind:value={chosenProposal} placeholder="Input your proposal ID"/>
      <!-- <button on:click={setProposal(chosenProposal)}>Vote!</button> -->
    {/await}

    <!-- {#if $proposalToVote.proposalID != "null"}
      {#await getProposalPromise}
        <h2 class="slogan">Loading...</h2>
      {:then res}
        <div class="votingdiv">
          <h3 class="slogan">
            Cast your vote on proposal ID: {$proposalToVote.proposalID}
          </h3>
          <div class="form-buttons">
            <button on:click={() => handleVoteClick(true)}>Yes</button>
            <button on:click={() => handleVoteClick(false)}>No</button>
            {#if $hasVoted === true}
              {#await votePromise}
                <h1 class="slogan">Loading...</h1>
              {:then res2}
                <p style="color: white">
                  Voted successfully! Current votes: {res2}
                </p>
              {:catch error}
                <p style="color: red">{error.message}</p>
              {/await}
            {/if}
          </div>
          <button on:click={() => setProposal("null")}
            >Choose new proposal</button
          >
        </div>
      {:catch error}
        <button on:click={() => setProposal("null")}
          >Wrong Proposal ID, click here to reset</button
        >
        <p style="color: red">{error.message}</p>
      {/await}
    {/if} -->
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">Connect with a wallet to access this example</p>
  {/if}
</div>

<style>
  .post-preview {
    background-color: wheat;
    border: 1px solid white;
    border-radius: 10px;
    margin-bottom: 2vmin;
    padding: 2vmin;
  }
  input {
    width: 100%;
    padding: 12px 20px;
    margin: 8px 0;
    display: inline-block;
    border: 1px solid #ccc;
    border-radius: 4px;
    box-sizing: border-box;
  }

  .bg {
    height: 55vmin;
    animation: pulse 3s infinite;
  }

  .votemain {
    display: flex;
    flex-direction: column;
    justify-content: center;
  }

  button {
    background-color: #4caf50;
    border: none;
    color: white;
    padding: 15px 32px;
    text-align: center;
    text-decoration: none;
    display: inline-block;
    font-size: 16px;
    margin: 4px 2px;
    cursor: pointer;
  }
  .vote-button:hover {
    transform: scale(1.15);
    transition: all 0.4s;
  }
</style>
