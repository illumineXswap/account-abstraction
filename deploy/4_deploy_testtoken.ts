import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

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

  const paymaster = await ethers.getContractAt('LuminexTokenPaymaster', (await hre.deployments.get('LuminexTokenPaymaster')).address)
  const token = await ethers.getContractAt('TestToken', tokenDeploy.address)

  // console.log(from, await paymaster.owner())

  // if (token.newlyDeployed) {
  const a = await paymaster.setFee(token.address, {
    flat: 10n,
    proportionalDenominator: 1,
    proportionalNumerator: 0
  }, { from })
  const s = await a.wait()
  // console.log(s)
  // }

  // console.log(await paymaster.feeConfigs(token.address))

  await token.mint('0x95025C01BaA559A9c293673e006628Be31C22C94', 10_000_000)

  // if (!await paymaster.trustedAccountFactories(entrypoint.address)) {
  //   await paymaster.trustAccountFactory(entrypoint.address)
  //   console.log('Trusted account factory set', entrypoint.address)
  // }
}

export default deploySimpleAccountFactory
