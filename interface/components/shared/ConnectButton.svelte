<script>
  import { onMount, beforeUpdate, afterUpdate } from 'svelte';
  import { login, logout, verifyConnectionAndAgent } from "../../auth"
  import { isAuthenticated } from "../../stores"

  console.log("ConnectButton -> isAuthenticated:", $isAuthenticated);
  $: message = $isAuthenticated ? "Logout" : "Sign in"
  $: buttonAdditionalClass = $isAuthenticated ? "logout" : "";

  onMount(async () => {
    console.log("ConnectButton -> onMount");
		const res = await verifyConnectionAndAgent();
    console.log("ConnectButton -> verifyConnectionAndAgent -> res", res, "isAuthenticated", $isAuthenticated);
	});

  beforeUpdate(() => {
		console.log("ConnectButton -> beforeUpdate - isAuthenticated", $isAuthenticated);
	});

	afterUpdate(() => {
		console.log("ConnectButton -> afterUpdate - isAuthenticated", $isAuthenticated);
	});
</script>

<button class="connect-button {buttonAdditionalClass}" on:click={() => $isAuthenticated ? logout() : login()}>
  {message}
</button>

<style>
  .connect-button {
    font-size: 18px;
    background: rgb(35 35 39);
    color: #fff;
    border: none;
    padding: 10px 20px;
    display: flex;
    align-items: center;
    border-radius: 40px;
    cursor: pointer;
  }
  .connect-button.logout {
    background: rgb(216 216 233);
    color: #000;
  }

  .connect-button:hover {
    transform: scale(1.1);
    transition: all 0.4s;
  }
</style>
