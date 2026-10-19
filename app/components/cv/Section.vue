<script setup lang="ts">
interface Props {
  title: string
  variant?: 'main' | 'sidebar'
}

withDefaults(defineProps<Props>(), {
  variant: 'main',
})
</script>

<template>
  <section class="cv-section" :class="`cv-section--${variant}`">
    <h2 class="cv-section__title outfit">{{ title }}</h2>
    <div class="cv-section__body">
      <slot />
    </div>
  </section>
</template>

<style scoped lang="scss">
.cv-section + .cv-section {
  margin-top: 2.25rem;
}

.cv-section__title {
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 1.375rem;
  font-weight: 500;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid;
}

.cv-section__body {
  margin-top: 1rem;
}

.cv-section--sidebar {
  .cv-section__title {
    color: var(--sys-color-white);
    border-bottom-color: rgb(255 255 255 / 0.65);
  }

  .cv-section__body {
    color: rgb(255 255 255 / 0.92);
  }
}

.cv-section--main {
  .cv-section__title {
    color: var(--cv-ink);
    border-bottom-color: var(--cv-rule);
  }

  .cv-section__body {
    color: var(--cv-ink);
  }
}
</style>
