<script>
  import { Principal } from "@dfinity/principal";
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import {isAuthenticated, accountId, principal, authSessionData, daoActor, webpageActor, daoCanisterId} from "../stores"
  import { decodeUtf8, getSystemParams, getFormattedToken, getStakedTokens } from "../lib.js"
  import mot from "../assets/mot.png"
  import dfinityLogo from "../assets/dfinity.svg"
  import { get } from "svelte/store"
  import {
    webpage as insecureWebActor,
    idlFactory,
  } from "../../src/declarations/webpage"

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:   DEFINITIONS   ----------   ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  let tokensToStake = ""
  let usingInsecureWebpageAgent = true

  let stakingDurationOptions = [
    { id: 6, text: `6 Months` },
    { id: 12, text: `1 Year` },
    { id: 24, text: `2 Years` },
    { id: 4, text: `4 Years` },
    { id: 6, text: `6 Years` },
    { id: 8, text: `8 Years` },
  ];
  let durationToStake
  let stakeTokensPromise

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:     STAKING     ----------   ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  // Grab the staken tokens payload
  let getStakedTokensPromise = getStakedTokens(get(daoActor))

  /**
   * Click event handler for stacking tokens
   * @param {number} stakedTokensAmount Staking amount, in integer
   * @param {number} chosenStakingDuration Staking duration, in months
   */
  function stakeTokens(stakedTokensAmount, chosenStakingDuration) {
    console.log("EVENT --- stakeTokens", stakedTokensAmount, chosenStakingDuration)

    if (stakedTokensAmount > 0 && chosenStakingDuration >= 6) {
      stakeTokensPromise = handleStakeTokens(stakedTokensAmount, chosenStakingDuration)
    }
  }

  /**
   * Call the DAO and stake the tokens.
   * @param {number} stakedTokensAmount Staking amount, in integer
   * @param {number} chosenStakingDuration Staking duration, in months
   */
  async function handleStakeTokens(stakedTokensAmount, chosenStakingDuration) {
    console.log("EVENT --- handleStakeTokens", stakedTokensAmount, chosenStakingDuration)
    let dao = get(daoActor)
    let response

    if (!dao) {
      return
    }

    // Prepare the payload for the DAO call.
    let payload = (idlFactory.Record = {
      amount: (idlFactory.Record = {
        amount_e8s: stakedTokensAmount
      }),
      duration: chosenStakingDuration
    })

    try {
      // Fetch the response and handle it in async fashion so we don't get the promise errors in console.
      response = await dao
      .stake(payload)
      .then((response) => {
        if (response.ok) {
          return response.ok
        } else {
          throw new Error(response.err)
        }
      })
      .catch((error) => {
        console.log("Error staking (1) - ", payload, error)
        throw new Error(error)
      })
    } catch (error) {
      // Catch-all in case something else goes wrong.
      console.log("Error staking (2) - ", thisID, error)
      throw new Error(error)
    }

    return response
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

    if (!$isAuthenticated || !webpage) {
      usingInsecureWebpageAgent = true
      webpage = insecureWebActor
      // console.log("Could not use secure webpage agent")
    } else {
      // console.log("Using secure webpage agent")
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
  //  REGION:      SVELTE      LIFECYCLE      HOOKS     ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------

  onMount(async () => {
    // console.log("Home -> onMount")
  })

  beforeUpdate(() => {
    // console.log("Home -> beforeUpdate - isAuthenticated", $isAuthenticated)
    // Grab the staken tokens payload
    getSystemParamsPromise = getSystemParams(get(daoActor));
    getStakedTokensPromise = getStakedTokens(get(daoActor))
  })

  afterUpdate(() => {
    // console.log("Home -> afterUpdate - isAuthenticated", $isAuthenticated)
  })
</script>

<div class="home-main">
  {#if $isAuthenticated}
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
  {/if}

  <!-- Render the webpage contents that we want to change via proposals. -->
  {#await getWebpageContentsPromise}
    <h3 class="slogan">Loading...</h3>
  {:then webpageContents}
    <div class="params-container">
      <h3>
        Current Webpage Contents ({usingInsecureWebpageAgent ? "From Insecure Actor" : "From Secure Actor"})
      </h3>
      {webpageContents}
    </div>
  {:catch error}
    <p style="color: red">{error.message}</p>
  {/await}

  <!-- Render the staking UI. -->
  {#if $isAuthenticated}
    <!-- User has authenticated with a wallet app. -->
    <!-- <img src={mot} class="bg" alt="logo" /> -->
    <h1 class="slogan">Your Staked MBT Tokens</h1>
    {#await getStakedTokensPromise}
      <h3 class="slogan">Loading...</h3>
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

    <h1 class="slogan">Stake your MBT Tokens</h1>
    <p>
      You must first stake your MBT tokens before you can create and vote on proposals.<br />
      Please enter the amount you want to stake and the duration you want to stake them for.
    </p>
    <div class="form-buttons">
      <input name="tokensToStake" type="number" bind:value={tokensToStake} placeholder="Tokens to stake"/>
      <select name="durationToStake" bind:value={durationToStake}>
        {#each stakingDurationOptions as option}
          <option value={option.id}>
            {option.text}
          </option>
        {/each}
      </select>
      <button on:click={stakeTokens(tokensToStake, durationToStake)}>Stake {tokensToStake} MBT Tokens!</button>
    </div>
    
    {#await stakeTokensPromise}
      <p style="color: white">...waiting</p>
    {:then stakeTokensResponse}
      {#if stakeTokensResponse}
        <p style="color: white">Your tokens have been successfully staked.</p>
      {/if}
    {:catch error}
      <p style="color: red">
        Your tokens could not be staked.<br />
        {error.message}
      </p>
    {/await}
  {:else}
    <!-- User has not authenticated with a wallet app. -->
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">You must be authenticated before you can interact with this app. Please connect with a wallet.</p>
  {/if}
</div>

<style>
  .home-main {
    display: flex;
    flex-direction: column;
    justify-content: center;
    color: white;
  }
</style>
