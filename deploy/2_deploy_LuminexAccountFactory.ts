import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deployLuminexAccountFactory: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypoint = await hre.deployments.get('EntryPoint')
  const deploy = await hre.deployments.deploy(
    'LuminexAccountFactory', {
      from,
      args: [from, entrypoint.address],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })

  const factory = await hre.ethers.getContractAt("LuminexAccountFactory", deploy.address);

  const CALL_MANAGER = await factory.CALL_MANAGER();
  if(!await factory.hasRole(CALL_MANAGER, from)){
    const tx = await factory.grantRole(CALL_MANAGER, from);
    await tx.wait();
    console.log(`  Granted LuminexAccountFactory.CALL_MANAGER to ${from}`)
  }

  console.log(`  LuminexAccountFactory.accountImplementation = ${await factory.callStatic.accountImplementation()}`)
}

export default deployLuminexAccountFactory
