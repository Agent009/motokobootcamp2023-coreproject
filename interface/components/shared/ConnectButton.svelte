<script>
  import { plugConnection } from "../connexion"
  export let message = "Sign in"
</script>

<button class="connect-button" on:click={() => plugConnection()}> {message} </button>

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

  .connect-button:hover {
    transform: scale(1.03);
    transition: all 0.4s;
  }
</style>
