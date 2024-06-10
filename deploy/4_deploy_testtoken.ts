import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import assert from 'node:assert'
import { WNATIVE } from './const'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  // const tokenDeploy = await hre.deployments.deploy(
  //   'TestToken', {
  //     from,
  //     gasLimit: 6e6,
  //     log: true,
  //     deterministicDeployment: true
  //   })
  //
  // const secondTokenDeploy = await hre.deployments.deploy(
  //   'TestToken', {
  //     from,
  //     gasLimit: 6e6,
  //     log: true,
  //     deterministicDeployment: '0xbeef'
  //   })

  /// ////////////////////////////

  const pMATIC = '0x1c4d39340e4c16f1F6E18891B927332604894231'
  const pwROSE = '0x1Ffd8A218FDc5B38210D64CBB45F40DC55A4e019'

  const tokensToSetOracles = [pMATIC, pwROSE]
  const prices = new Map<string, [nativeReceived: bigint, tokenCost: bigint]>([
    [pMATIC, [618455n, 100000n]],
    [pwROSE, [1n, 1n]]
  ])

  const chainId = hre.network.config.chainId
  assert(typeof chainId === 'number', 'ChainId must be a number')
  const wNativeAddress = WNATIVE[chainId]

  if (wNativeAddress?.length === 0) {
    console.log('  WNATIVE not set. Skipping oracle configuration')
  }

  const paymaster = await ethers.getContractAt('LuminexTokenPaymaster', (await hre.deployments.get('LuminexTokenPaymaster')).address)

  const txs = []
  for (const tokenAddress of tokensToSetOracles) {
    const oracleResult = await hre.deployments.deploy(
      'LuminexOracleConst', {
        from,
        args: [from, wNativeAddress, tokenAddress],
        gasLimit: 6e6,
        log: true,
        deterministicDeployment: true
      })

    const oracle = await ethers.getContractAt('LuminexOracleConst', oracleResult.address)

    const price = prices.get(tokenAddress)
    const val = await Promise.all([oracle.token0Value(), oracle.token1Value()])
    if ((price != null) && (price[0] !== val[0].toBigInt() || price[1] !== val[1].toBigInt())) {
      const tx = await oracle.setValues(price[0], price[1])
      txs.push(tx.wait().then(() => {
        console.log(`  Oracle (${oracle.address}) price set [${price.join()}]`)
      }).catch(e => {
        console.log({ tokenAddress: tokenAddress, oracleAddress: oracleResult.address, price })
        throw e
      }))
    }

    if (await paymaster.oracles(tokenAddress) === oracleResult.address) {
      continue
    }

    const tx = (await paymaster.setOracle(tokenAddress, oracleResult.address))
    txs.push(tx.wait().catch(e => {
      console.log({ tokenAddress: tokenAddress, oracleAddress: oracleResult.address })
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
