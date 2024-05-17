import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypointDeployment = await hre.deployments.get('EntryPoint')
  const paymasterDeployed = await hre.deployments.deploy(
    'LuminexTokenPaymaster', {
      from,
      args: [entrypointDeployment.address, from],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  // const paymaster = await ethers.getContractAt('LuminexTokenPaymaster', paymasterDeployed.address)

  // if (!await paymaster.trustedAccountFactories(entrypoint.address)) {
  //   await paymaster.trustAccountFactory(entrypoint.address)
  //   console.log('Trusted account factory set', entrypoint.address)
  // }
}

export default deploySimpleAccountFactory
