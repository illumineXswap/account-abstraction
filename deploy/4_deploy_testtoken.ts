import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import assert from 'node:assert'
import { WNATIVE } from './const'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const tokenDeploy = await hre.deployments.deploy(
    'TestToken', {
      from,
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  const secondTokenDeploy = await hre.deployments.deploy(
    'TestToken', {
      from,
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: '0xbeef'
    })

  /// ////////////////////////////

  const tokensToSetOracles = [tokenDeploy.address, secondTokenDeploy.address]

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

  // console.log(await paymaster.feeConfigs(token.address))

  // await token.mint('0x95025C01BaA559A9c293673e006628Be31C22C94', 10_000_000)
  // await token.mint('0xF450fd80f8b8D37aB4f2d5f4b4F32a64500872F7', 10_000n * 10n ** 18n)
  // await token.mint('0x0E0271498d31F20d02D6fc8D8074058F1C7F9Aee', 10_000n * 10n ** 18n)
}

export default deploySimpleAccountFactory
