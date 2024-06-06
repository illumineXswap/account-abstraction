import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deployLuminexAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypoint = await hre.deployments.get('EntryPoint')
  await hre.deployments.deploy(
    'LuminexAccountFactory', {
      from,
      args: [from, entrypoint.address],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  // await hre.deployments.deploy('TestCounter', {
  //   from,
  //   log: true,
  //   deterministicDeployment: true
  // })
}

export default deployLuminexAccountFactory
