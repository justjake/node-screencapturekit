const buildPath = '../.build'
const basename = 'Module.node'
const releasePath = `${process.arch}-apple-macosx/release`

function requireNativeModule() {
  try {
    return require(`${buildPath}/${basename}`)
  } catch (error) {
    if ((error as any).code === 'MODULE_NOT_FOUND') {
      return require(`${buildPath}/${releasePath}/${basename}`)
    }
    throw error
  }
}

const NativeModule = requireNativeModule()
export { NativeModule }