import '@oasisprotocol/sapphire-hardhat'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import { HardhatUserConfig } from 'hardhat/types/config'
import 'hardhat-deploy'
import '@nomiclabs/hardhat-etherscan'
import 'dotenv/config'

import 'solidity-coverage'

import * as fs from 'fs'

const mnemonicFileName = process.env.MNEMONIC_FILE ?? `${process.env.HOME}/.secret/testnet-mnemonic.txt`
let mnemonic = 'test '.repeat(11) + 'junk'
if (fs.existsSync(mnemonicFileName)) { mnemonic = fs.readFileSync(mnemonicFileName, 'ascii') }

function getNetwork1 (url: string): { url: string, accounts: { mnemonic: string } } {
  return {
    url,
    accounts: { mnemonic }
  }
}

function getNetwork (name: string): { url: string, accounts: { mnemonic: string } } {
  return getNetwork1(`https://${name}.infura.io/v3/${process.env.INFURA_ID}`)
  // return getNetwork1(`wss://${name}.infura.io/ws/v3/${process.env.INFURA_ID}`)
}

const optimizedComilerSettings = {
  version: '0.8.23',
  settings: {
    optimizer: { enabled: true, runs: 1000000 },
    viaIR: true
  }
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: '0.8.23',
      settings: {
        optimizer: { enabled: true, runs: 1000000 }
      }
    }],
    overrides: {
      'contracts/core/EntryPoint.sol': optimizedComilerSettings,
      'contracts/samples/SimpleAccount.sol': optimizedComilerSettings
    }
  },
  networks: {
    dev: getNetwork1('http://localhost:8545'),
    // github action starts localgeth service, for gas calculations
    localgeth: getNetwork1('http://localhost:8545'),
    sapphire_local: { ...getNetwork1('http://localhost:8545'), chainId: 0x5afd },
    sapphire: { ...getNetwork1('https://sapphire.oasis.io'), chainId: 0x5afe },
    sapphire_testnet: { ...getNetwork1('https://testnet.sapphire.oasis.io'), chainId: 0x5aff },
    goerli: getNetwork('goerli'),
    sepolia: getNetwork('sepolia'),
    proxy: getNetwork1('http://localhost:8545')
  },
  mocha: {
    timeout: 10000
  },
  deterministicDeployment: {
    0x5aff: {
      funding: '10000000000000000',
      deployer: '0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37',
      signedTx: '0xf8a78085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf382b622a044ac748b68fe9b7ae964f2a272637b422b06981c8690ff57fa535c3a09851b69a060bc54c8ecc62cc2565c30a7be4b044c8e1997084b69e9036108818d13eaa2bf',
      factory: '0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7'
    },
    0x5afe: {
      funding: '10000000000000000',
      deployer: '0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37',
      signedTx: '0xf8a78085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf382b620a0322f1c093633d4d1ace847573bf236ba2f66210952824ac47d65b445fedfb985a058b9dbaf0a2f88df0116ceb3d49b489ca7d5e72932802ac12885dc0e3ada3903',
      factory: '0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7'
    }
  }
}

// coverage chokes on the "compilers" settings
if (process.env.COVERAGE != null) {
  // @ts-ignore
  config.solidity = config.solidity.compilers[0]
}

export default config
