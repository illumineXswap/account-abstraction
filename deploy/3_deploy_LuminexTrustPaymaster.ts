import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { ethers } from 'hardhat'
import assert from 'node:assert'
import { WNATIVE } from './const'
import { LuminexAccountFactory, LuminexTokenPaymaster } from '../typechain'
import registeredTokens from '../tokens.json'

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider
  const signer = provider.getSigner()
  const from = await signer.getAddress()

  const chainId = hre.network.config.chainId
  assert(typeof chainId === 'number', 'ChainId must be a number')

  const factoryDeployed = await hre.deployments.get('LuminexAccountFactory')

  const entrypointDeployment = await hre.deployments.get('EntryPoint')
  const paymasterDeployed = await hre.deployments.deploy(
    'LuminexTokenPaymaster', {
      from,
      args: [entrypointDeployment.address, from, WNATIVE[chainId], factoryDeployed.address],
      gasLimit: 6e6,
      log: true,
      deterministicDeployment: true
    })


  const factory = await hre.ethers.getContractAt('LuminexAccountFactory', factoryDeployed.address)
  const paymaster = await hre.ethers.getContractAt('LuminexTokenPaymaster', paymasterDeployed.address)


  const BALANCE_VIEWER = await factory.BALANCE_VIEWER();
  if(!await factory.hasRole(BALANCE_VIEWER, paymasterDeployed.address)) {
    const tx = await factory.grantRole(BALANCE_VIEWER, paymasterDeployed.address);
    await tx.wait();
  }

  if (paymasterDeployed.newlyDeployed)
    await approveCalls(factory, paymaster)

  const entryPoint = await ethers.getContractAt('EntryPoint', entrypointDeployment.address)

  const targetDeposit = 2n * 10n ** 18n
  const currentDeposit = (await entryPoint.balanceOf(paymasterDeployed.address)).toBigInt()
  if (currentDeposit < targetDeposit / 2n) {
    const a = await entryPoint.depositTo(paymasterDeployed.address, {
      value: targetDeposit - currentDeposit
    })
    await a.wait()
    console.log(`  Deposited ${targetDeposit - currentDeposit} for paymaster`)
  }

  const targetBalance = 1n * 10n ** 18n
  const currentBalance = (await provider.getBalance(paymasterDeployed.address)).toBigInt()
  if (currentBalance < targetBalance / 2n) {
    const value = targetBalance - currentBalance
    console.log({ value })
    const a = await signer.sendTransaction({
      to: paymasterDeployed.address,
      value: value
    })
    await a.wait()
    console.log(`  Sent ${targetBalance - currentBalance} to paymaster`)
  }
}
deploySimpleAccountFactory.skip = async (env) => {
  const chainId = env.network.config.chainId
  return WNATIVE[chainId ?? -1] === undefined
}

export default deploySimpleAccountFactory

async function approveCalls(factory: LuminexAccountFactory, paymaster: LuminexTokenPaymaster) {
  const selector = (abiString: string): string => {
    return ethers.utils.solidityKeccak256(["string"], [abiString]).slice(0, 10)
  }


  const foreignTargetAllowedCalls = {
    // BalanceRegistry
    '0xaA12E7aB0Ed8dd1814979bc6bd21E2aC17CD2F0E': [
      selector('getHeldTokens(uint256,uint256)')
    ],
    // SapphireEndpoint
    '0xDd1Ee07b46C7eD888671a646F3c7a37394e8cF85': [
      selector('proxyPass(address,uint256,bytes)')
    ]
  }

  const getSelectorsWhitelist = (): Record<string, string[]> => {
    const paymasterTargetAllowedCalls = {
      [paymaster.address]: [
        selector('buyNativeForToken(address,uint256,uint256,address)'),
        selector('tokensRequiredForNative(address,uint256)'),
        selector('debt(address,address)'),
      ]
    }

    const tokensAllowedCalls = Object.fromEntries(
      registeredTokens.tokens
        .filter((token) => token.extensions?.illuminexWrapper)
        .map((token) => ([
          token.address,
          [
            selector('transfer(address,uint256)'),
            selector('approve(address,uint256)'),
            selector('transferFrom(address,address,uint256)'),
            selector('balanceOf(address)')
          ]
        ]))
    )

    return {
      ...foreignTargetAllowedCalls,
      ...paymasterTargetAllowedCalls,
      ...tokensAllowedCalls
    }
  }

  const allowedCalls = getSelectorsWhitelist()
  for (const [target, selectors] of Object.entries(allowedCalls)) {
    const tx = await factory.allowCalls(target, selectors)
    console.log({ tx });
    await tx.wait();
  }
}