import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import assert from 'node:assert'
import { WNATIVE } from './const'
import registeredTokens from '../tokens.json'

const deploySimpleAccountFactory: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  ////////////////////////////////

  /*
  1 BNB = 5388 ROSE
  1 USDT BSC = 9.173699832 ROSE
  1 ETH ETH = 39878.8 ROSE
  1 USDC ETH = 10.841645261367047 ROSE
  1 USDT ETH = 10.841645261367047 ROSE
  1 ETH ARBITRUM = 36812.04274074493 ROSE
  1 MATIC = 6.505047202855522 ROSE
  1 IX = 7.201971511492144 ROSE
  1 OCEAN = 12.443690162457884 ROSE
  */

  const tokensToSetOracles = registeredTokens.tokens
    .filter((token) => token.extensions?.illuminexWrapper)
  const prices = new Map<string, [nativeReceived: bigint, tokenCost: bigint]>([
    ['pbscBNB', [5388n, 1n]],
    ['pbscUSDT', [9173n, 1000n]],
    ['pethETH', [398788n, 10n]],
    ['pethUSDC', [1084164n, 100000n]],
    ['pethUSDT', [1084164n, 100000n]],
    ['parbETH', [3681204n, 100n]],
    ['ppolygonMATIC', [650504n, 100000n]],
    ['pIX', [72019n, 10000n]],
    ['pOCEAN', [12443n, 1000n]],
    ['pwROSE', [1n, 1n]],
  ])

  const chainId = hre.network.config.chainId
  assert(typeof chainId === 'number', 'ChainId must be a number')
  const wNativeAddress = WNATIVE[chainId]

  if (wNativeAddress?.length === 0) {
    console.log('  WNATIVE not set. Skipping oracle configuration')
  }

  const paymaster = await ethers.getContractAt('LuminexTokenPaymaster', (await hre.deployments.get('LuminexTokenPaymaster')).address)

  const txs = []
  for (const token of tokensToSetOracles) {
    const oracleResult = await hre.deployments.deploy(
      'LuminexOracleConst', {
      from,
      args: [from, wNativeAddress, token.address],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

    const oracle = await ethers.getContractAt('LuminexOracleConst', oracleResult.address)

    const price = prices.get(token.symbol)
    const val = await Promise.all([oracle.token0Value(), oracle.token1Value()])
    if ((price != null) && (price[0] !== val[0].toBigInt() || price[1] !== val[1].toBigInt())) {
      const tx = await oracle.setValues(price[0], price[1])
      txs.push(tx.wait().then(() => {
        console.log(`  Oracle ${token.symbol} (${oracle.address}) price set [${price.join()}]`)
      }).catch(e => {
        console.log({ tokenAddress: token.address, oracleAddress: oracleResult.address, price })
        throw e
      }))
    }

    if (await paymaster.oracles(token.address) === oracleResult.address) {
      continue
    }

    const tx = (await paymaster.setOracle(token.address, oracleResult.address))
    txs.push(tx.wait().catch(e => {
      console.log({ tokenAddress: token.address, oracleAddress: oracleResult.address })
      throw e
    }))
  }
  for (const result of await Promise.allSettled(txs)) {
    if (result.status === 'rejected') {
      console.error(result.reason)
    }
  }
}

export default deploySimpleAccountFactory
