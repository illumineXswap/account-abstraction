import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deployLuminexAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const simulationsDeployment = await hre.deployments.deploy(
    'EntryPointSimulations', {
      from,
      args: [],
      gasLimit: 6e6,
      log: true
    })
  const entrypointDeployed = await hre.deployments.get('EntryPoint')
  const entryPoint = await ethers.getContractAt('EntryPoint', entrypointDeployed.address)

  if (!await entryPoint.trustedDelegates(simulationsDeployment.address)) {
    await entryPoint.trustDelegate(simulationsDeployment.address)
    console.log('Trust simulation delegate', simulationsDeployment.address)
  }
}

export default deployLuminexAccountFactory
