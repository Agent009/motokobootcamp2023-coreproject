<script>
  import { useCanister } from "@connect2ic/svelte"

  let count
  const [backend, { loading }] = useCanister("backend")

  const refreshbackend = async () => {
    const freshCount = await $backend.getValue()
    count = freshCount
  }

  const increment = async () => {
    await $backend.increment()
    await refreshbackend()
  }

  $: {
    if (!$loading && $backend) {
      refreshbackend()
    }
  }

</script>
<div class="example">
  <p style="font-size: 2.5em;">{count?.toString()}</p>
  <button class="connect-button" on:click={increment}>+</button>
</div>
