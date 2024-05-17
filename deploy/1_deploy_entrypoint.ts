import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const deployEntryPoint: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const from = await provider.getSigner().getAddress()

  const entrypointDeployment = await hre.deployments.deploy(
    'EntryPoint',
    {
      from,
      args: [],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    }
  )

  const entryPoint = await ethers.getContractAt('EntryPoint', entrypointDeployment.address)

  void entryPoint
  // await entryPoint.depositTo('0x95025C01BaA559A9c293673e006628Be31C22C94', {
  //   value: 200000000000000000n
  // })
  // console.log((await entryPoint.balanceOf('0x95025C01BaA559A9c293673e006628Be31C22C94')).toBigInt() - 34985600000000000n)
}

export default deployEntryPoint
