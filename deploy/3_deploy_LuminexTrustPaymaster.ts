import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import assert from 'node:assert'
import { WNATIVE } from './const'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const chainId = hre.network.config.chainId
  assert(typeof chainId === 'number', 'ChainId must be a number')

  const entrypointDeployment = await hre.deployments.get('EntryPoint')
  const paymasterDeployed = await hre.deployments.deploy(
    'LuminexTokenPaymaster', {
      from,
      args: [entrypointDeployment.address, from, WNATIVE[chainId]],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  const entryPoint = await ethers.getContractAt('EntryPoint', entrypointDeployment.address)

  const targetDeposit = 2n * 10n ** 18n
  const currentDeposit = (await entryPoint.balanceOf(paymasterDeployed.address)).toBigInt()
  if (currentDeposit < targetDeposit) {
    const a = await entryPoint.depositTo(paymasterDeployed.address, {
      value: targetDeposit - currentDeposit
    })
    await a.wait()
    console.log(`  Deposited ${targetDeposit - currentDeposit} for paymaster`)
  }
}
deploySimpleAccountFactory.skip = async (env) => {
  const chainId = env.network.config.chainId
  return WNATIVE[chainId ?? -1] === undefined
}

export default deploySimpleAccountFactory
