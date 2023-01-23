<script>
  import { get } from "svelte/store"
  import Proposal from "./Proposal.svelte"
  import { daoActor, principal } from "../stores"
  import dfinityLogo from "../assets/dfinity.svg"
  import { getAllProposals } from "../lib.js"

  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  //  REGION:    PROPOSALS     RELATED     ----------   ----------   ----------   ----------   ----------
  //----------   ----------   ----------   ----------   ----------   ----------   ----------   ----------
  
  let allProposalsPromise = getAllProposals(get(daoActor))
</script>

<div class="view-proposal">
  {#if $principal}
    {#await allProposalsPromise}
      <p>Loading...</p>
    {:then proposals}
      {(console.log("proposals: ", proposals), '')}

      {#if proposals}
        <div id="proposals">
          <h1>Proposals</h1>
          {#each proposals as post}
            {(console.log("proposal: ", post), '')}
            <Proposal {post} />
          {/each}
        </div>
      {:else}
        <p style="color: red">No proposals exist yet.</p>
      {/if}
    {:catch error}
      <p style="color: red">{error.message}</p>
    {/await}
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">You must be authenticated before you can view the proposals. Please connect with a wallet.</p>
  {/if}
</div>

<style>
  .view-proposal {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
  }
  h1 {
    color: white;
    font-size: 10vmin;
    font-weight: 700;
  }

  #proposals {
    display: flex;
    flex-direction: column;
    width: 100%;
    margin-left: 10vmin;
  }
</style>
