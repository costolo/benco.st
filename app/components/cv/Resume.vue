<script setup lang="ts">
import { cv as bundledCv } from '~/data/cv'
import type { CvData } from '~/data/cv'

interface Props {
  data?: CvData
}

const props = defineProps<Props>()

const resume = computed<CvData>(() => props.data ?? bundledCv)
</script>

<template>
  <div class="cv">
    <aside class="cv__sidebar">
      <h1 class="cv__name outfit">{{ resume.profile.name }}</h1>

      <CvSection title="Skills" variant="sidebar">
        <div v-for="group in resume.skills" :key="group.title" class="cv-skillgroup">
          <h3 class="cv-skillgroup__title outfit">{{ group.title }}</h3>
          <p class="cv-skillgroup__items poppins">{{ group.items.join(' · ') }}</p>
        </div>
      </CvSection>

      <CvSection title="Education" variant="sidebar">
        <div v-for="entry in resume.education" :key="`${entry.degree}-${entry.institution}`" class="cv-edu">
          <h3 class="cv-edu__degree outfit">{{ entry.degree }}</h3>
          <p class="cv-edu__institution poppins">{{ entry.institution }}</p>
          <p class="cv-edu__dates poppins">{{ entry.start }} – {{ entry.end }}</p>
        </div>
      </CvSection>
    </aside>

    <main class="cv__main">
      <header class="cv__header">
        <p class="cv__title outfit">{{ resume.profile.title }}</p>
        <ul class="cv__contact poppins">
          <li v-for="item in resume.profile.contact" :key="item.label" class="cv__contact-item">
            <span v-if="item.icon" class="cv__contact-icon" :class="item.icon" aria-hidden="true" />
            <a
              v-if="item.href"
              :href="item.href"
              :target="item.external ? '_blank' : undefined"
              :rel="item.external ? 'noopener' : undefined"
            >{{ item.label }}</a>
            <span v-else>{{ item.label }}</span>
          </li>
        </ul>
      </header>

      <CvSection title="Experience" variant="main">
        <CvExperienceEntry
          v-for="entry in resume.experience"
          :key="`${entry.company}-${entry.start}`"
          :entry="entry"
        />
      </CvSection>
    </main>
  </div>
</template>

<style scoped lang="scss">
.cv {
  --cv-sidebar: #0e6b60;
  --cv-accent: #17a2b8;
  --cv-bg: #f7f9fa;
  --cv-ink: #1f2933;
  --cv-muted: #52606d;
  --cv-rule: #cbd2d9;

  display: grid;
  grid-template-columns: minmax(16rem, 22rem) 1fr;
  width: 64rem;
  max-width: 100%;
  margin: 0 auto;
  background-color: var(--cv-bg);
  color: var(--cv-ink);
}

@media (max-width: 48rem) {
  .cv {
    grid-template-columns: 1fr;
  }
}

.cv__sidebar {
  background-color: var(--cv-sidebar);
  padding: 2.5rem 2rem;
}

.cv__name {
  text-transform: uppercase;
  font-size: 2.25rem;
  line-height: 1.15;
  font-weight: 500;
  color: var(--sys-color-white);
  margin-bottom: 2.5rem;
}

.cv__main {
  padding: 2.5rem 2.5rem 3rem;
}

.cv__title {
  font-size: 1.5rem;
  font-weight: 500;
  color: var(--cv-accent);
}

.cv__contact {
  margin-top: 0.75rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem 1.25rem;
  font-size: 0.875rem;
  color: var(--cv-muted);
}

.cv__contact-item {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;

  a {
    color: inherit;
    text-decoration: none;
  }

  a:hover {
    text-decoration: underline;
  }
}

.cv__contact-icon {
  display: inline-block;
  width: 1em;
  height: 1em;
  flex: none;
}

.cv-skillgroup + .cv-skillgroup,
.cv-edu + .cv-edu {
  margin-top: 1.25rem;
}

.cv-skillgroup__title,
.cv-edu__degree {
  font-size: 1.0625rem;
  font-weight: 500;
  color: var(--sys-color-white);
}

.cv-skillgroup__items {
  margin-top: 0.375rem;
  font-size: 0.875rem;
  line-height: 1.7;
}

.cv-edu__institution {
  margin-top: 0.25rem;
  font-size: 0.9375rem;
}

.cv-edu__dates {
  margin-top: 0.25rem;
  font-size: 0.8125rem;
  opacity: 0.8;
}
</style>
