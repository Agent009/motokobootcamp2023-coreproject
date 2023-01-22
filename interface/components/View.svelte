<script>
  import Proposal from "./Proposal.svelte"
  import { get } from "svelte/store"
  import { daoActor, principal } from "../stores"
  import dfinityLogo from "../assets/dfinity.svg"

  /**
   * Get all the proposals
   */
  async function get_all_proposals() {
    let dao = get(daoActor)

    if (!dao) {
      return
    }

    let res;
    console.log("get_all_proposals");

    try {
      res = await dao.get_all_proposals()
    } catch (error) {
      console.log("Error getting all proposals", error);
      throw new Error(error)
    }

    console.log("Proposals", res)
    return res
  }
  
  let promise = get_all_proposals()
</script>

<div class="view-proposal">
  {#if $principal}
    {#await promise}
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
