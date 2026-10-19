<script setup lang="ts">
useBaseHead({ title: 'benco.st', description: '' })
</script>

<template>
  <div class="flex flex-col h-full">
    <BaseNavigation />
    <main class="bg-pink p-6 flex-1 h-full">
      <slot />
    </main>
  </div>
</template>
