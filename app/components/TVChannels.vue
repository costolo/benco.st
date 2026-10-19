<script setup lang="ts">
const { gifUrl } = useTvChannel()
</script>

<template>
  <section>
    <div
      id="gif-container"
      class="bg-cover bg-center"
      :style="{ backgroundImage: `url(${gifUrl})` }"
    ></div>
  </section>
</template>

<style scoped>
section,
div {
  height: 100%;
  width: 100%;
}
</style>
