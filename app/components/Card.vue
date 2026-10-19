<script setup lang="ts">
import colors from '~/assets/theme.json'

interface Props {
  color?: string
  gridRow?: string
  gridColumn?: string
  fullScreen?: boolean
  noPadding?: boolean
  fixedWidth?: string
  scroll?: boolean
  center?: boolean
  widthString?: string
}

const props = withDefaults(defineProps<Props>(), {
  gridRow: 'auto',
  gridColumn: 'auto',
})

const { og } = colors.cards

// Rolled once per request and reused during hydration, so the colour cannot
// differ between the server render and the client.
const rolledColor = useState<string | undefined>(
  `brutal-card:${useId()}`,
  () => og[Math.floor(Math.random() * og.length)]
)

const cardColor = computed(() =>
  props.color ?? (props.noPadding ? undefined : rolledColor.value)
)
</script>

<template>
  <div
    class="brutal-card"
    :class="{ fullScreen, noPadding, scroll, center }"
    :style="{
      '--color': cardColor,
      '--gridRow': gridRow,
      '--gridColumn': gridColumn,
    }"
  >
    <slot />
  </div>
</template>

<style scoped lang="scss">
div.brutal-card {
  grid-row: var(--gridRow);
  grid-column: var(--gridColumn);
  position: relative;
  background-color: var(--color);
  border-radius: 0.5rem;
  border: 3px solid black;
  filter: drop-shadow(7px 7px 0 rgb(0 0 0 / 1));
  transition: all;
  padding: 1rem;
  transition-duration: 0.5s;
  animation: ease-in-out;
  overflow: hidden;
  width: fit-content;

  // Lowercase on purpose: the template emits `fullScreen`, so this never
  // matches. Astro shipped the same dead rule and the layout depends on it.
  &.fullscreen {
    height: 100%;
    width: 100%;
  }

  &.noPadding {
    padding: unset;
  }

  &.scroll {
    height: 80vh;
    overflow: scroll;
  }

  &.center {
    margin: 0 auto;
  }
}

div.brutal-card:hover {
  filter: drop-shadow(5px 5px 0 rgb(0 0 0 / 1));
}
</style>
