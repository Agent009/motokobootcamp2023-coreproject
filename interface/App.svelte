<script>
  import { onMount, beforeUpdate, afterUpdate } from "svelte"
  import * as dao from "../src/declarations/dao"
  import { verifyConnectionAndAgent } from "./auth"
  import {
    isAuthenticated,
    accountId,
    principal,
    authSessionData,
    daoActor,
    webpageActor,
    view,
  } from "./stores"
  import Sidebar from "./components/Sidebar.svelte"
  import Header from "./components/shared/Header.svelte"
  import Home from "./components/Home.svelte"
  import Vote from "./components/Vote.svelte"
  import View from "./components/View.svelte"
  import Create from "./components/Create.svelte"

  /*onMount(async () => {
    console.log("App onMount");
		const res = await verifyConnectionAndAgent();
    console.log("App -> verifyConnectionAndAgent -> res", res);
	});*/

  beforeUpdate(() => {
    console.log("App -> beforeUpdate - isAuthenticated", $isAuthenticated)
  })

  afterUpdate(() => {
    console.log("App -> afterUpdate - isAuthenticated", $isAuthenticated)
  })
</script>

<div class="App">
  <header class="header">
    <Header />
  </header>
  <main class="main">
    <Sidebar />
    {#if $view.current === $view.home}
      <Home />
    {:else if $view.current === $view.view}
      <View />
    {:else if $view.current === $view.vote}
      <Vote />
    {:else if $view.current === $view.create}
      <Create />
    {/if}
    <div class="styling" />
  </main>
  <footer>
    <p class="twitterfoot">
      by <a href="https://twitter.com/">Moi</a>
    </p>
  </footer>
</div>

<style global>
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto",
      "Oxygen", "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans",
      "Helvetica Neue", sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    color: #424242;
    background-color: #262626;
  }
  .header {
    display: flex;
    flex-direction: row;
    flex-wrap: nowrap;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 15px;
  }
  .styling {
    width: 5vmin;
  }
  .main {
    display: flex;
    justify-content: space-between;
  }
  button {
    font-weight: 600;
    background-color: #4c4a4a;
  }
  .slogan {
    font-size: 1.7em;
    margin-bottom: 0;
    color: #ffffff;
  }
  .twitter {
    font-size: 0.4em;
    color: #ffffff;
  }
  a {
    color: inherit;
  }
  .twitterfoot {
    position: fixed;
    color: #ffffff;
    bottom: 0;
    right: 0;
    margin-right: 2vmin;
    font-size: 1em;
    font-weight: 600;
  }
  .App-logo {
    height: 14vmin;
    pointer-events: none;
    transform: scale(1);
    animation: pulse 3s infinite;
  }
  footer {
    position: fixed;
    bottom: 0;
  }
  .footerimg {
    position: fixed;
    bottom: 0;
    right: 100px;
    height: 5vmin;
    pointer-events: none;
  }
  .App-header {
    height: calc(100vh - 70px);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    font-size: calc(10px + 2vmin);
  }
  .examples {
    padding: 30px 100px;
    display: grid;
    grid-gap: 30px;
    grid-template-columns: 1fr 1fr 1fr;
  }
  .examples-title {
    font-size: 1.3em;
    margin-bottom: 0;
    text-align: center;
  }
  .example {
    padding: 50px 50px;
    min-height: 300px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    border-radius: 15px;
  }
  .example-disabled {
    font-size: 1.3em;
    color: #ffffff;
  }
  .demo-button {
    background: #a02480;
    padding: 0 1.3em;
    margin-top: 1em;
    border-radius: 60px;
    font-size: 0.7em;
    height: 35px;
    outline: 0;
    border: 0;
    cursor: pointer;
    color: white;
  }
  .demo-button:active {
    color: white;
    background: #979799;
  }
  @keyframes pulse {
    0% {
      transform: scale(0.97);
      opacity: 0;
    }
    70% {
      transform: scale(1);
      opacity: 1;
    }
    100% {
      transform: scale(0.97);
      opacity: 0;
    }
  }
  /**
 * Correct font family set oddly in Safari 5 and Chrome.
 */
  code,
  kbd,
  pre,
  samp {
    font-family: monospace, serif;
    font-size: 1em;
  }

  /**
 * Improve readability of pre-formatted text in all browsers.
 */
  pre {
    white-space: pre-wrap;
  }
  pre {
    background-color: #f2f5f6;
    padding: 3px;
    border-top: 1px solid #d6d6d6;
    border-bottom: 1px solid #d6d6d6;
    font-family: Consolas, "Andale Mono WT", "Andale Mono", "Lucida Console",
      "Lucida Sans Typewriter", "DejaVu Sans Mono", "Bitstream Vera Sans Mono",
      "Liberation Mono", "Nimbus Mono L", Monaco, "Courier New", Courier,
      monospace;
    line-height: 10px;
    color: #444;
    overflow: hidden;
    overflow-y: hidden;
    overflow-x: auto;
    margin: 10px 0;
  }
  pre code {
    border: 0;
    padding: 0;
    line-height: 1.3;
  }
  code {
    border-radius: 2px;
    background-color: #d6d6d6;
    border: 1px solid #b2b2b2;
    display: inline-block;
    padding: 0 5px;
    line-height: inherit;
    font-size: inherit;
    color: inherit;
    margin: 0 3px;
    font-family: Consolas, "Andale Mono WT", "Andale Mono", "Lucida Console", "Lucida Sans Typewriter", "DejaVu Sans Mono", "Bitstream Vera Sans Mono", "Liberation Mono", "Nimbus Mono L", Monaco, "Courier New", Courier, monospace;
    border-color: #eee;
    background-color: #f2f5f6;
    font-size: 12px;
    line-height: 1.65em;
  }
</style>
