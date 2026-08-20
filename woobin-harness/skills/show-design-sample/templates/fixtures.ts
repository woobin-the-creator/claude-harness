const TEXT_SEED = 'X'
const ID_SEED = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

function repeatToLength(seed: string, length: number) {
  if (length <= 0 || seed.length === 0) {
    return ''
  }

  let output = ''
  while (output.length < length) {
    output += seed
  }
  return output.slice(0, length)
}

export function syntheticText(length: number) {
  return repeatToLength(TEXT_SEED, length)
}

export function syntheticId(length: number) {
  return repeatToLength(ID_SEED, length)
}
