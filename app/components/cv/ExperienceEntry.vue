<script setup lang="ts">
import type { CvExperienceEntry } from '~/data/cv'

interface Props {
  entry: CvExperienceEntry
}

defineProps<Props>()
</script>

<template>
  <article class="cv-job">
    <header class="cv-job__head">
      <div class="cv-job__ident">
        <h3 class="cv-job__role outfit">{{ entry.role }}</h3>
        <component
          :is="entry.companyUrl ? 'a' : 'span'"
          :href="entry.companyUrl"
          class="cv-job__company outfit"
          :target="entry.companyUrl ? '_blank' : undefined"
          :rel="entry.companyUrl ? 'noopener' : undefined"
        >
          {{ entry.company }}
        </component>
      </div>
      <div class="cv-job__meta poppins">
        <span class="cv-job__dates">{{ entry.start }} – {{ entry.end }}</span>
        <span class="cv-job__location">{{ entry.location }}</span>
      </div>
    </header>

    <p v-if="entry.summary" class="cv-job__summary poppins">{{ entry.summary }}</p>

    <ul v-if="entry.highlights.length" class="cv-job__highlights poppins">
      <li v-for="(highlight, index) in entry.highlights" :key="index">{{ highlight }}</li>
    </ul>
  </article>
</template>

<style scoped lang="scss">
.cv-job + .cv-job {
  margin-top: 1.75rem;
}

.cv-job__head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.25rem 1.5rem;
  align-items: baseline;
}

.cv-job__role {
  font-size: 1.25rem;
  font-weight: 500;
  color: var(--cv-ink);
}

.cv-job__company {
  display: block;
  margin-top: 0.125rem;
  font-size: 1.125rem;
  color: var(--cv-accent);
  text-decoration: none;
}

a.cv-job__company:hover {
  text-decoration: underline;
}

.cv-job__meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  text-align: right;
  font-size: 0.875rem;
  color: var(--cv-muted);
}

.cv-job__summary {
  margin-top: 0.625rem;
  font-size: 0.9375rem;
  line-height: 1.5;
}

.cv-job__highlights {
  margin-top: 0.5rem;
  padding-left: 1.125rem;
  list-style: disc;
  font-size: 0.9375rem;
  line-height: 1.5;

  li {
    margin-top: 0.375rem;
    padding-left: 0.25rem;
  }

  li::marker {
    color: var(--cv-accent);
  }
}
</style>
