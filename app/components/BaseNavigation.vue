<script setup lang="ts">
defineProps<{
  pageTitle?: string
}>()
</script>

<template>
  <header
    class="border-b-4 border-black flex items-center justify-between p-6"
  >
    <h1 class="hidden">{{ pageTitle }}</h1>
    <NuxtLink to="/">
      <p class="hidden-joke-trigger righteous text-4xl md:text-5xl lg:text-7xl">
        benco<span class="righteous text-sm hidden-joke">stolo, go home</span>
      </p>
    </NuxtLink>
    <nav>
      <NuxtLink to="/uhf">
        <div class="circle bg-[url(/images/sineWave.svg)]"></div>
      </NuxtLink>
    </nav>
  </header>
</template>

<style scoped lang="scss">
@keyframes move {
  0% {
    background-position: 0 0;
  }

  100% {
    background-position: -100px 0;
  }
}

.circle {
  height: 48px;
  width: 48px;
  border-radius: 100%;
  border: 6px solid #000;
  animation: move 6s infinite alternate-reverse;
}

.hidden-joke {
  opacity: 0;
  transition: opacity 0.25s ease-out 0.5s;
}

.hidden-joke-trigger:hover {
  .hidden-joke {
    opacity: 1;
  }
}
</style>
