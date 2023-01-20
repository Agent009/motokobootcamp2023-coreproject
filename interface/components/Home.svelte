<script>
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import {
    isAuthenticated,
    accountId,
    principal,
    authSessionData,
    daoActor,
    webpageActor,
  } from "../stores"
  import { decodeUtf8 } from "../lib.js"
  import { proposalToVote } from "../stores.js"
  import { hasVoted } from "../stores.js"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { get } from "svelte/store"
  import {
    webpage as insecureWebActor,
    idlFactory,
  } from "../../src/declarations/webpage"

  let chosenProposal = ""
  let chosenVote = ""
  let voteId = ""
  let id = ""
  let usingInsecureWebpageAgent = true

  async function vote(thisid, votepayload) {
    let dao = get(daoActor)

    if (!dao) {
      return
    }
    let res = await dao.vote(BigInt(thisid), votepayload)

    if (res.Ok) {
      return res.Ok
    } else {
      throw new Error(res.Err)
    }
  }

  async function get_proposal(thisid) {
    let dao = get(daoActor)

    if (!dao) {
      return
    }

    let res = await dao.get_proposal(BigInt(thisid))

    if (res.length !== 0) {
      return res[0]
    } else {
      throw new Error(
        "Could not find this proposal, make sure you typed in the right ID",
      )
    }
  }

  async function get_webpage(url, method) {
    let webpage = get(webpageActor)

    if (!$isAuthenticated || !webpage) {
      usingInsecureWebpageAgent = true
      webpage = insecureWebActor
      console.log("Could not use secure webpage agent")
    } else {
      console.log("Using secure webpage agent")
      usingInsecureWebpageAgent = false
    }

    if (!webpage) {
      console.log("Could not use insecure webpage agent either")
      return
    }

    let headers = (idlFactory.Vec = [])
    let body = (idlFactory.Vec = [])
    let httpRequest = (idlFactory.Record = {
      url: url,
      method: method,
      body: body,
      headers: headers,
    })

    let res = await webpage.http_request(httpRequest)
    // console.log(typeof res === undefined, res.status_code, decodeUtf8(res.body), res)

    if (typeof res !== undefined && res.status_code === 200) {
      return decodeUtf8(res.body)
    } else {
      throw new Error("Could not load webpage contents.")
    }
  }

  let votePromise = vote(voteId, chosenVote)
  let getProposalPromise = get_proposal(id)
  let getWebpageContentsPromise = get_webpage("/", "GET")

  function handleVoteClick(payload) {
    chosenVote = payload
    voteId = id
    votePromise = vote(voteId, chosenVote)
    $hasVoted = true
  }

  function handleProposalCheck(payload) {
    id = payload
    getProposalPromise = get_proposal(id)
  }

  //I assume the vote Yes/No will be represented as True/False
  function setProposal(x) {
    $proposalToVote.proposalID = x

    if (x != "null") {
      handleProposalCheck(x)
    }
  }

  onMount(async () => {
    console.log("Home -> onMount");
	});

  beforeUpdate(() => {
		console.log("Home -> beforeUpdate - isAuthenticated", $isAuthenticated);
	});

	afterUpdate(() => {
		console.log("Home -> afterUpdate - isAuthenticated", $isAuthenticated);
	});
</script>

<div class="votemain">
  {#await getWebpageContentsPromise}
    <h1 class="slogan">Loading...</h1>
  {:then res3}
    <div class="webpage">
      <h3>
        Current Webpage Contents ({usingInsecureWebpageAgent
          ? "From Insecure Actor"
          : "From Secure Actor"})
      </h3>
      {res3}
    </div>
  {:catch error}
    <p style="color: red">{error.message}</p>
  {/await}

  {#if $isAuthenticated}
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
  .webpage {
    background: white;
    color: black;
    border: 1px solid black;
    padding: 20px;
    margin: 20px auto;
    display: block;
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

  .delete {
    background-color: white;
  }
</style>
