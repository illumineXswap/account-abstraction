import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypoint = await hre.deployments.get('EntryPoint')
  const paymasterDeployed = await hre.deployments.deploy(
    'LuminexTrustPaymaster', {
      from,
      args: [entrypoint.address],
      gasLimit: 6e6,
      log: true
    })

  const paymaster = await ethers.getContractAt('LuminexTrustPaymaster', paymasterDeployed.address)

  if (!await paymaster.trustedAccountFactories(entrypoint.address)) {
    await paymaster.trustAccountFactory(entrypoint.address)
    console.log('Trusted account factory set', entrypoint.address)
  }
}

export default deploySimpleAccountFactory
