<script setup lang="ts">
const isMobile = useIsMobile()
</script>

<template>
  <Card v-if="isMobile" full-screen>
    <p class="mt-4 outfit text-4xl md:text-5xl lg:text-7xl">Apologies,</p>
    <p class="mt-4 outfit text-lg md:text-xl lg:text-2xl">
      This content can only be viewed on large tablets and desktops.
    </p>
    <NuxtLink
      to="/"
      title="Go back home"
      class="block mt-4 px-4 py-2 border-2 border-black transition-colors duration-150 ease-in-out w-48 text-center poppins"
    >
      &larr; Go Home
    </NuxtLink>
    <Ocean />
  </Card>
  <Card v-else scroll center no-padding>
    <CvResume />
  </Card>
</template>
