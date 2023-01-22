<script>
  import { onMount, beforeUpdate, afterUpdate } from 'svelte';
  import { balance, login, logout, verifyConnectionAndAgent } from "../../auth"
  import { isAuthenticated, accountId, principalId } from "../../stores"

  console.log("ConnectButton -> isAuthenticated:", $isAuthenticated);
  $: message = $isAuthenticated ? "Logout" : "Sign in"
  $: buttonAdditionalClass = $isAuthenticated ? "logout" : "";
  // $: loggedInClass = $isAuthenticated ? "logged-in" : "";
  // $: ourAccountID = $accountId ? $accountId : "___";
  // $: ourPrincipalID = $principalId ? $principalId : "Anonymous";

  /*async function getBalance(symbol) {
    let response = await balance(symbol)

    if (response) {
      return response.amount
    }
  }

  let icpBalance = getBalance('ICP');*/

  onMount(async () => {
    // console.log("ConnectButton -> onMount");
		// const res = await verifyConnectionAndAgent();
    // console.log("ConnectButton -> verifyConnectionAndAgent -> res", res, "isAuthenticated", $isAuthenticated);
	});

  beforeUpdate(() => {
		// console.log("ConnectButton -> beforeUpdate - isAuthenticated", $isAuthenticated);
	});

	afterUpdate(() => {
		// console.log("ConnectButton -> afterUpdate - isAuthenticated", $isAuthenticated);
	});
</script>

<button class="connect-button {buttonAdditionalClass}" on:click={() => $isAuthenticated ? logout() : login()}>
  {message}
</button>

<style>
  .connect-button {
    background-color: #376e65;
    color: #8cbbb4;
    font-size: 1.5em;
    border: none;
    border-radius:10px;
    padding: 10px 20px;
    display: flex;
    align-items: center;
    cursor: pointer;
  }
  .connect-button.logout {
    background: rgb(216 216 233);
    color: #000;
  }

  .connect-button:hover {
    transform: scale(1.15);
    transition: all 0.4s;
  }
</style>
