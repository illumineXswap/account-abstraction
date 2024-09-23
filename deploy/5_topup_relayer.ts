import type { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'

const topupRelayer: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const provider = ethers.provider
  const signer = provider.getSigner()

  const relayerAddress = '0x39db935312Eb70ff6BB2D0298Ee1fE13cd34af63'

  const targetBalance = 2n * 10n ** 18n
  const currentBalance = (await provider.getBalance(relayerAddress)).toBigInt()
  if (currentBalance < targetBalance / 2n) {
    const a = await signer.sendTransaction({
      to: relayerAddress,
      value: targetBalance - currentBalance
    })
    await a.wait()
    console.log(`  Deposited ${targetBalance - currentBalance} for relayer`)
  }
  
  const paymasterDeployed = await hre.deployments.get('LuminexTokenPaymaster')
  const paymaster = await hre.ethers.getContractAt('LuminexTokenPaymaster', paymasterDeployed.address)

  const isTrusted = await paymaster.callStatic.trustedSigners(relayerAddress)
  if (!isTrusted) {
    const tx = await paymaster.setSignerTrust(relayerAddress, true)
    await tx.wait()
    console.log(`  Set trusted signer ${relayerAddress}`)
  }
}

export default topupRelayer
