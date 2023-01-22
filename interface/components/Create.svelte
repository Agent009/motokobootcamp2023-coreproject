<script>
  import { IDL } from "@dfinity/candid";
  import { Principal } from "@dfinity/principal";
  import { daoActor, principal } from "../stores"
  import { get } from "svelte/store"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { idlFactory } from "../../src/declarations/dao"
  import { textToUnit8Array } from "../lib.js"
  import { createEventDispatcher } from "svelte"

  // TODO: Fetch webpage canister ID via canister call and use that as the default value
  let proposalCanisterID = "ryjl3-tyaaa-aaaaa-aaaba-cai"
  let proposalCanisterMethod = "update_page_title"
  let proposalCanisterMessage = "Page title modified at: " + new Date().toUTCString()
  let proposalSummary = "This proposal intends to...";

  async function create_proposal(canisterID, canisterMethod, canisterMessage, summary) {
    let dao = get(daoActor)

    if (!dao) {
      return
    }

    let res;
    console.log("Preparing to submit proposal.");
    let payload = (idlFactory.Record = {
      canister_message: textToUnit8Array(proposalCanisterMessage),
      canister_id: Principal.from(proposalCanisterID),
      proposal_summary: proposalSummary,
      canister_method: proposalCanisterMethod,
    });
    console.log("Payload prepared.", payload);

    try {
      res = await dao.submit_proposal(payload)
    } catch (error) {
      console.log("Error submitting proposal", payload, error);
      throw new Error(error)
    }

    if (res.ok) {
      return res.ok
    } else {
      console.log("Error creating proposal", res.err);
      throw new Error(res.err)
    }
  }
  
  let createProposalPromise;

  /**
   * Handle the click event to create a new proposal.
   * @param canisterID
   * @param canisterMethod
   * @param canisterMessage
   * @param summary
   */
  function handleProposalCreateEvent(canisterID, canisterMethod, canisterMessage, summary) {
    console.log("--- EVENT --- handleProposalCreateEvent --- proposalCanisterID", canisterID, "proposalCanisterMethod", canisterMethod);
    console.log("proposalCanisterMessage", canisterMessage, "proposalSummary", summary);
    proposalCanisterID = canisterID;
    proposalCanisterMethod = canisterMethod;
    proposalCanisterMessage = canisterMessage;
    proposalSummary = summary;

    createProposalPromise = create_proposal(canisterID, canisterMethod, canisterMessage, summary)
  }
</script>

<div class="votemain">
  {#if $principal}
    <img src={mot} class="bg" alt="logo" />
    <h1 class="slogan">Create a proposal</h1>
    <input name="proposalCanisterID" bind:value={proposalCanisterID} placeholder="Canister ID"/>
    <input name="proposalCanisterMethod" bind:value={proposalCanisterMethod} placeholder="Canister Method"/>
    <input name="proposalCanisterMessage" bind:value={proposalCanisterMessage} placeholder="Canister Mesage"/>
    <input name="proposalSummary" bind:value={proposalSummary} placeholder="Canister Mesage"/>
    <button on:click={handleProposalCreateEvent(proposalCanisterID, proposalCanisterMethod, proposalCanisterMessage, proposalSummary)}>Create!</button>

    {#await createProposalPromise}
      <p style="color: white">...waiting</p>
    {:then newProposalID}
      {#if newProposalID}
        <p style="color: white">The proposal was created successfully. The proposal ID is: {newProposalID}</p>
      {/if}
    {:catch error}
      <p style="color: red">
        The proposal couldn't be created.
        {error.message}
      </p>
    {/await}
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">You must be authenticated before you can submit a proposal. Please connect with a wallet.</p>
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
