<script>
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import { proposalToVote } from "../stores.js"
  import { hasVoted } from "../stores.js"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { get } from "svelte/store"
  import { daoActor, principal } from "../stores"

  let chosenProposal = ""
  let chosenVote = ""
  let voteId = ""
  let id = ""

  async function vote(thisID, votePayload) {
    let dao = get(daoActor)
    let res

    if (!dao) {
      return
    }

    await dao
      .vote(BigInt(thisID), votePayload)
      .then((response) => {
        if (response.Ok) {
          return response.Ok
        } else {
          throw new Error(rresponsees.Err)
        }
      })
      .catch((error) => {
        console.log("Error voting", thisID, votePayload, error)
        throw new Error(error)
      })
  }

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

  let votePromise
  let getProposalPromise

  function handleVoteClick(payload) {
    console.log("EVENT --- handleVoteClick", payload)
    chosenVote = payload
    voteId = id
    votePromise = vote(voteId, chosenVote)
    $hasVoted = true
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
  }

  onMount(async () => {
    console.log("Vote -> onMount")
  })

  beforeUpdate(() => {
    console.log("Vote -> beforeUpdate")
  })

  afterUpdate(() => {
    console.log("Vote -> afterUpdate")
  })
</script>

<div class="votemain">
  {#if $principal}
    <img src={mot} class="bg" alt="logo" />
    {#if $proposalToVote.proposalID === "null"}
      <h1 class="slogan">Please input a proposal ID!</h1>
      <input
        bind:value={chosenProposal}
        placeholder="Input your proposal ID here"
      />
      <button on:click={setProposal(chosenProposal)}>Vote!</button>
    {:else if $proposalToVote.proposalID != "null"}
      {#await getProposalPromise}
        <h1 class="slogan">Loading...</h1>
      {:then res}
        <div class="votingdiv">
          <h1 class="slogan">
            You are voting on proposal ID: {$proposalToVote.proposalID}
          </h1>
          <div>
            <h1 class="slogan">Cast your vote:</h1>
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
    {/if}
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">Connect with a wallet to access this example</p>
  {/if}
</div>

<style>
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
  .votingdiv {
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-bottom: 5vmin;
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
</style>
