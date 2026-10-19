const INITIAL_GIF = '/images/television_channels/78.gif'
const CHANNEL_COUNT = 103

const generateGifURL = (): string =>
  `/images/television_channels/${Math.floor(Math.random() * CHANNEL_COUNT)}.gif`

export const useTvChannel = () => {
  const gifUrl = useState<string>('tv:gif-url', () => INITIAL_GIF)

  const setNewGif = () => {
    let next = generateGifURL()
    if (next === gifUrl.value) {
      // reroll if same value is rolled, just once tho
      next = generateGifURL()
    }
    gifUrl.value = next
  }

  return { gifUrl, setNewGif }
}
