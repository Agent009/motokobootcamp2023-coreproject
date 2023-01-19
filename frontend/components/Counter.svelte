<script>
  import { useCanister } from "@connect2ic/svelte"

  let count
  const [dao, { loading }] = useCanister("dao")

  const refreshdao = async () => {
    const freshCount = await $dao.getValue()
    count = freshCount
  }

  const increment = async () => {
    await $dao.increment()
    await refreshdao()
  }

  $: {
    if (!$loading && $dao) {
      refreshdao()
    }
  }

</script>
<div class="example">
  <p style="font-size: 2.5em;">{count?.toString()}</p>
  <button class="connect-button" on:click={increment}>+</button>
</div>
