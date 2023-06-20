import '@nomiclabs/hardhat-waffle'
import 'hardhat-contract-sizer'
import 'hardhat-abi-exporter'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'

const COMPILER_SETTINGS = {
  optimizer: {
    enabled: true,
    runs: 1000000
  },
  metadata: {
    bytecodeHash: 'none'
  }
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  abiExporter: {
    path: './abi'
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test'
  },
  solidity: {
    compilers: [
      {
        version: '0.8.0',
        settings: COMPILER_SETTINGS
      }
    ]
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false
  }
}
