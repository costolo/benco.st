<script setup lang="ts">
import { getFile, playSample } from '~/lib/audio'

const { setNewGif } = useTvChannel()

const isOn = ref(false)

let audioContext: AudioContext | null = null
let onClickBuffer: AudioBuffer | null = null
let offClickBuffer: AudioBuffer | null = null
let singleClickBuffers: AudioBuffer[] = []

onMounted(async () => {
  audioContext = new AudioContext()

  const [onClick, offClick, ...singleClicks] = await Promise.all([
    getFile(audioContext, '/sounds/on_click.wav'),
    getFile(audioContext, '/sounds/off_click.wav'),
    getFile(audioContext, '/sounds/single_click1.wav'),
    getFile(audioContext, '/sounds/single_click2.wav'),
    getFile(audioContext, '/sounds/single_click3.wav'),
    getFile(audioContext, '/sounds/single_click4.wav'),
  ])

  onClickBuffer = onClick
  offClickBuffer = offClick
  singleClickBuffers = singleClicks
})

onBeforeUnmount(() => {
  audioContext?.close()
  audioContext = null
})

const play = async (buffer: AudioBuffer | null | undefined) => {
  if (!audioContext || !buffer) return
  // The context is created before any user gesture, so it starts suspended.
  await audioContext.resume()
  await playSample(audioContext, buffer, 0)
}

const onPowerClick = () => {
  isOn.value = !isOn.value
  play(isOn.value ? onClickBuffer : offClickBuffer)
}

const onChannelClick = () => {
  play(singleClickBuffers[Math.floor(Math.random() * 4)])
  if (isOn.value) {
    setNewGif()
  }
}
</script>

<template>
  <section class="main-content">
    <div class="tv" :class="isOn ? 'on' : 'off'">
      <div class="antenna-container hidden md:flex h-21.25 w-58.75">
        <div class="antenna"></div>
      </div>
      <div class="television-container h-75 w-75 md:h-150 md:w-225">
        <div class="television">
          <div class="television-inner">
            <div class="television-screen-container">
              <div class="television-crt">
                <div class="television-screen">
                  <div class="on"></div>
                  <div class="noise"></div>
                  <div class="content">
                    <TVChannels />
                  </div>
                </div>
              </div>
            </div>
            <div class="television-lateral">
              <div class="buttons">
                <div class="button-container">
                  <div class="button" @click="onChannelClick"></div>
                </div>
                <div class="button-container">
                  <div class="button" @click="onPowerClick"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<!-- Deliberately unscoped: Astro emitted these on a bare `:root`, and scoping
     them would stop them reaching the elements that read them. -->
<style>
:root {
  --television-bgcolor: #b71a11;
  --television-bgcolor-dark: #88110b;
  --antenna-gradient: linear-gradient(
    to top,
    #444 10%,
    #999 25% 40%,
    #444 70%,
    #2224 90%
  );
}
</style>

<style scoped lang="scss">
.main-content {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-top: 1em;
}

.tv {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  width: 100%;

  & .antenna-container {
    display: none;
    flex-direction: column;
    justify-content: flex-end;

    & .antenna {
      width: 100%;
      height: 4px;
      background: var(--antenna-gradient);
      transform-origin: 100% 50%;
      transform: rotate(20deg) translateY(3px);
      z-index: 0;
      display: flex;
      align-items: center;

      &::before {
        content: "";
        display: block;
        width: 8px;
        height: 10px;
        background: var(--antenna-gradient);
        border-radius: 24% 53% 53% 24% / 36% 40% 40% 36%;
        border: 1px solid #444;
        border-left: 0;
        border-bottom: 0;
        transform: translateY(-1px);
      }
    }
  }

  & .television-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    z-index: 1;

    & .television {
      border-radius: 22px / 22px;
      box-shadow:
        2px 2px 5px #0004,
        2px -2px 2px var(--television-bgcolor) inset,
        2px 1px 1px #fff inset,
        0 0 3px 5px #0002;
      background: repeating-radial-gradient(
        var(--television-bgcolor),
        var(--television-bgcolor-dark)
      );
      display: flex;
      justify-content: center;
      align-items: center;
      z-index: 2;
      height: 100%;
      width: 100%;

      & .television-inner {
        padding: 2em;
        box-shadow: 0 1px 2px var(--television-bgcolor-dark) inset;
        border-radius: 25px / 25px;
        position: relative;
        height: 100%;
        width: 100%;

        & .television-screen-container {
          box-shadow:
            0 2px 2px #888,
            2px 0 2px #444,
            -2px 0 2px #444,
            0 -2px 2px #111;
          border-radius: 35px / 25px;
          background:
            linear-gradient(70deg, #555 15%, transparent 30%),
            repeating-conic-gradient(#222 0 30deg, #333 60deg, #222 90deg);
          height: 100%;
          width: 100%;

          & .television-crt {
            width: 99%;
            height: 95%;
            background: #111;
            box-shadow:
              0 0 5px 2px #111,
              0 0 10px 2px #1112;
            border-radius: 85px 85px 85px 85px / 100px 100px 100px 100px;
            overflow: hidden;
            display: flex;
            justify-content: center;
            align-items: center;

            & .television-screen {
              background: #302d30;
              width: 100%;
              height: 100%;
              border-radius: 30%;
              box-shadow: 0 0 5px 2px #111 inset;
              overflow: hidden;
              position: relative;

              & .noise {
                width: 100%;
                height: 100%;
                background:
                  linear-gradient(
                    to bottom,
                    transparent,
                    #aaa4,
                    #8881,
                    #6664,
                    #4445,
                    #2228,
                    #4443,
                    transparent
                  ),
                  repeating-linear-gradient(transparent 0 2px, #25242950 2px 4px);
                animation: moveBand 8s linear infinite;
                z-index: 4;
                position: relative;
              }

              & .content {
                position: absolute;
                top: 0;
                width: 100%;
                height: 100%;
                background:
                  linear-gradient(
                    to bottom,
                    transparent,
                    #aaa4,
                    #8881,
                    #6664,
                    #4445,
                    #2228,
                    #4443,
                    transparent
                  ),
                  repeating-linear-gradient(transparent 0 2px, #25242950 2px 4px);
                animation: moveBand 8s linear infinite;
              }

              & .on {
                width: 100%;
                height: 100%;
                background: radial-gradient(#222, #1a1a1a, #111);
                z-index: 5;
                position: absolute;
                top: 0;
              }
            }
          }
        }

        & .television-lateral {
          display: grid;
          grid-template-rows: 1.1fr 1fr;
          gap: 12px;
          margin: 15px;
          margin-left: 0;
        }

        & .buttons {
          position: absolute;
          bottom: 5px;
          right: 30px;
          width: 60px;
          display: flex;
          justify-content: space-between;

          & .button-container {
            width: 20px;
            height: 20px;
            background: linear-gradient(to bottom, #fff 40%, #aaa 50% 55%, #666 70%);
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;

            & .button {
              width: 10px;
              height: 10px;
              border-radius: 50%;
              background: linear-gradient(to top, #fff 40%, #aaa 50% 55%, #666 70%);
              box-shadow: -1px -1px 1px 2px #000;
              transform: translate(2px, 1px);
              transition:
                transform 0.1s,
                box-shadow 0.1s;
              cursor: pointer;
            }
          }
        }
      }
    }
  }
}

/* Animation */

.tv .on {
  transition: opacity 0.5s;
  opacity: 1;
}

.tv:not(.off) .on {
  opacity: 0;
}

@keyframes moveBand {
  0% {
    background-position-y: 0, 0;
  }
  100% {
    background-position-y: -221px, -150px;
  }
}
</style>
