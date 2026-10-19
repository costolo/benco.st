<script setup lang="ts">
useBaseHead({ title: 'Page Not Found', description: 'Page not found' })
</script>

<template>
  <div class="flex flex-col h-full">
    <BaseNavigation page-title="Page Not Found!" />
    <main class="bg-red px-6 py-24 h-full">
      <ErrorPage />
    </main>
  </div>
</template>
