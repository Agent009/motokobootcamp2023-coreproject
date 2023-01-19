<script>
  import Proposal from "./Proposal.svelte"
  import { get } from "svelte/store"
  import { daoActor, principal } from "../stores"
  import dfinityLogo from "../assets/dfinity.svg"

  async function get_all_proposals() {
    let dao = get(daoActor)
    if (!dao) {
      return
    }
    let res = await dao.get_all_proposals()
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
      <div id="proposals">
        <h1>Proposals</h1>
        {#each proposals as post}
          <Proposal {post} />
        {/each}
      </div>
    {:catch error}
      <p style="color: red">{error.message}</p>
    {/await}
  {:else}
    <img src={dfinityLogo} class="App-logo" alt="logo" />
    <p class="example-disabled">Connect with a wallet to access this example</p>
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
