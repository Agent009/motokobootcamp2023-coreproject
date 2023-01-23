<script>
  import { IDL } from "@dfinity/candid";
  import { Principal } from "@dfinity/principal";
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import { daoActor, webpageActor, principal, proposalSubmissionDeposit, isDevelopmentEnv, daoCanisterId, webpageCanisterId } from "../stores"
  import { get } from "svelte/store"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { idlFactory } from "../../src/declarations/dao"
  import { textToUnit8Array, decodeUtf8, getSystemParams, getFormattedToken, getStakedTokens } from "../lib.js"
  import { createEventDispatcher } from "svelte"

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:   DEFINITIONS   ----------   ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  let proposalCanisterID = webpageCanisterId
  let proposalCanisterMethod = "update_page_title"
  let proposalSummary = "This proposal intends to...";

  let canisterIDOptions = [
    { id: daoCanisterId, text: `DAO Canister - ` + daoCanisterId },
    { id: webpageCanisterId, text: `Webpage Canister - ` + webpageCanisterId }
  ];
  let daoCanisterMethodOptions = [
    { id: "transfer_fee", text: `Update transfer fee (token amount as an integer)` },
    { id: "proposal_vote_threshold", text: `Update proposal vote threshold (token amount as an integer)` },
    { id: "proposal_submission_deposit", text: `Update proposal submission deposit (token amount as an integer)` }
  ];
  let webpageCanisterMethodOptions = [
    { id: "update_page_title", text: `Update page title (enter text input)` },
    { id: "update_page_content", text: `Update page content (enter text input)` }
  ];
  $: daoCanisterSelected = proposalCanisterID === daoCanisterId;
  $: canisterMethodOptions = daoCanisterSelected ? daoCanisterMethodOptions : webpageCanisterMethodOptions;
  let showWebpageParameters = 1;
  let showDaoParameters = 2;
  $: parametersToShow = daoCanisterSelected ? showDaoParameters : showWebpageParameters;
  $: webpageCanisterMessageByMethod = !daoCanisterSelected && proposalCanisterMethod === "update_page_title" ? "title" : "content";
  $: proposalCanisterMessage = daoCanisterSelected ? "100000" : "Page " + webpageCanisterMessageByMethod + " modified at: " + new Date().toUTCString()

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:    PROPOSALS     RELATED     ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  async function create_proposal(canisterID, canisterMethod, canisterMessage, summary) {
    let dao = get(daoActor)

    if (!dao) {
      return
    }

    let res;
    let encodedCanisterMessage = await textToUnit8Array(canisterMessage);
    console.log("Preparing to submit proposal.");
    let payload = (idlFactory.Record = {
      canister_message: encodedCanisterMessage,
      canister_id: Principal.from(canisterID),
      proposal_summary: summary,
      canister_method: canisterMethod,
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

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:      GETTING    MODIFIABLE      DATA      ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  let getSystemParamsPromise = getSystemParams($daoActor);
  let getWebpageContentsPromise = get_webpage("/", "GET");

  /**
   * Get the current webpage contents, so we can display these nicely on the homepage, and allow the users to see the current content.
   * @param {string} url The URL to fetch, e.g. "/"
   * @param {string} method The method to invoke, e.g. "GET"
   */
  async function get_webpage(url, method) {
    let webpage = get(webpageActor)
    let response;

    if (!webpage) {
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
    // console.log("httpRequest payload prepared.", httpRequest)

    try {
      response = await webpage.http_request(httpRequest)
      .then((res) => {
        // console.log(typeof res === undefined, res.status_code, decodeUtf8(res.body), res)
        if (typeof res !== undefined && res.status_code === 200) {
          return decodeUtf8(res.body)
        } else {
          throw new Error("Could not load webpage contents.")
        }
      })
      .catch((error) => {
        console.log("Error getting webpage contents - ", httpRequest, error)
        throw new Error(error)
      })
    } catch (error) {
      console.log("Error getting response from webpage contents - ", httpRequest, error)
      throw new Error(error)
    }

    return response;
  }

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:     ACCOUNT       RELATED    ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  // Grab the staken tokens payload
  let getStakedTokensPromise = getStakedTokens(get(daoActor))

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:      SVELTE      LIFECYCLE      HOOKS     ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  onMount(async () => {
    // console.log("Home -> onMount")
  })

  beforeUpdate(() => {
    // console.log("Create -> beforeUpdate - isAuthenticated", $isAuthenticated)
    // Grab the staken tokens payload
    getSystemParamsPromise = getSystemParams(get(daoActor));
    getStakedTokensPromise = getStakedTokens(get(daoActor))
  })

  afterUpdate(() => {
    // console.log("Create -> afterUpdate - isAuthenticated", $isAuthenticated)
  })
</script>

<div class="create-proposal">
  {#if $principal}
    <!-- <img src={mot} class="bg" alt="logo" /> -->
    <h1 class="slogan">Create a proposal</h1>
    
    <textarea name="proposalSummary" bind:value={proposalSummary} placeholder="{proposalSummary}" rows="3" />
    <div class="form-buttons">
      <select name="proposalCanisterID" bind:value={proposalCanisterID}>
        {#each canisterIDOptions as option}
          <option value={option.id}>
            {option.text}
          </option>
        {/each}
      </select>
      <select name="proposalCanisterMethod" bind:value={proposalCanisterMethod}>
        {#each canisterMethodOptions as option}
          <option value={option.id}>
            {option.text}
          </option>
        {/each}
      </select>
    </div>
    <h3 class="params-heading">Current Parameters</h3>
    {#if parametersToShow === showDaoParameters}
      <!-- Render the system parameters. -->
      {#await getSystemParamsPromise}
      <h3 class="slogan">Loading...</h3>
      {:then systemParams}
        {#if systemParams}
          <div class="params-container">
            <ul class="inline">
              <li>
                <span>Transfer Fee</span>
                <pre><code>{getFormattedToken(systemParams.transfer_fee.amount_e8s)}</code></pre>
              </li>
              <li>
                <span>Proposal Submission Deposit</span>
                <pre><code>{getFormattedToken(systemParams.proposal_submission_deposit.amount_e8s)}</code></pre>
              </li>
              <li>
                <span>Proposal Vote Threshold</span>
                <pre><code>{getFormattedToken(systemParams.proposal_vote_threshold.amount_e8s)}</code></pre>
              </li>
            </ul>
          </div>
        {/if}
      {:catch error}
        <p style="color: red">System parameters couldn't be loaded.</p>
      {/await}
    {:else}
      <!-- Render the webpage contents that we want to change via proposals. -->
      {#await getWebpageContentsPromise}
      <h3 class="slogan">Loading...</h3>
      {:then webpageContents}
        <div class="params-container">
          {webpageContents}
        </div>
      {:catch error}
        <p style="color: red">{error.message}</p>
      {/await}
    {/if}
    <h3 class="params-heading">Specify New Parameter</h3>
    <input name="proposalCanisterMessage" bind:value={proposalCanisterMessage} placeholder="Canister Mesage" style="width:100%"/>
    <p class="wheat">
      Please note that creating a new proposal deducts {getFormattedToken($proposalSubmissionDeposit)} from your staked balance with the DAO.<br />
      This is to ensure that only quality proposals are submitted!<br />
      Your staked token stats are shown below.
    </p>
    {#await getStakedTokensPromise}
      <h3 class="slogan">Loading staking stats...</h3>
    {:then stakedTokens}
      {#if stakedTokens}
        <div class="params-container">
          <ul class="inline">
            <li>
              <span>Total Staked</span>
              <pre><code>{getFormattedToken(stakedTokens.balance.amount_e8s)}</code></pre>
            </li>
            <li>
              <span># Neurons</span>
              <pre><code>{stakedTokens.neurons.length}</code></pre>
            </li>
            <!--<li>
              <span>Details</span>
              <pre><code>{stakedTokens.message}</code></pre>
            </li>-->
          </ul>
        </div>
      {/if}
    {:catch error}
      <p style="color: red">Your staked token details couldn't be loaded.</p>
    {/await}
    <button on:click={handleProposalCreateEvent(proposalCanisterID, proposalCanisterMethod, proposalCanisterMessage, proposalSummary)}>Create!</button>

    {#await createProposalPromise}
      <p style="color: white">...waiting</p>
    {:then newProposalID}
      {#if newProposalID}
        <p style="color: white">The proposal was created successfully. The proposal ID is: {newProposalID}</p>
      {/if}
    {:catch error}
      <p style="color: red">
        The proposal couldn't be created.<br />
        {error.message}
      </p>
    {/await}
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">You must be authenticated before you can submit a proposal. Please connect with a wallet.</p>
  {/if}
</div>

<style>
  textarea {
    padding: 12px 20px;
    margin: 8px 0;
  }
  .create-proposal {
    display: flex;
    flex-direction: column;
    justify-content: center;
  }
</style>
