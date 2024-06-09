import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deployLuminexComplianceManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const afDeployment = await hre.deployments.get('LuminexAccountFactory')
  const af = await hre.ethers.getContractAt('LuminexAccountFactory', afDeployment.address)

  const cmDeployment = await hre.deployments.deploy(
    'LuminexAccountComplianceManager', {
      from,
      args: [from, afDeployment.address],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  await af.setComplianceManager(cmDeployment.address)
}

export default deployLuminexComplianceManager
