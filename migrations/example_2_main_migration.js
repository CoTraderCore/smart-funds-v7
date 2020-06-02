// // globals artifacts
// const ParaswapParams = artifacts.require('./paraswap/ParaswapParams.sol')
// const GetBancorAddressFromRegistry = artifacts.require('./bancor/GetBancorAddressFromRegistry.sol')
// const GetRatioForBancorAssets = artifacts.require('./bancor/GetRatioForBancorAssets.sol')
//
// const ExchangePortal = artifacts.require('./core/portals/ExchangePortal.sol')
// const PoolPortal = artifacts.require('./core/portals/PoolPortal.sol')
// const ConvertPortal = artifacts.require('./core/portals/ConvertPortal.sol')
//
// const PermittedExchanges = artifacts.require('./core/verification/PermittedExchanges.sol')
// const PermittedStabels = artifacts.require('./core/verification/PermittedStables.sol')
// const PermittedPools = artifacts.require('./core/verification/PermittedPools.sol')
//
// const TokensTypeStorage = artifacts.require('./core/storage/TokensTypeStorage.sol')
//
// const SmartFundETHFactory = artifacts.require('./core/SmartFundETHFactory.sol')
// const SmartFundUSDFactory = artifacts.require('./core/SmartFundUSDFactory.sol')
//
// const SmartFundRegistry = artifacts.require('./core/SmartFundRegistry.sol')
//
//
// // addresses
// const PARASWAP_NETWORK_ADDRESS = "0xF92C1ad75005E6436B4EE84e88cB23Ed8A290988"
// const PARASWAP_PRICE_ADDRESS = "0xC6A3eC2E62A932B94Bac51B6B9511A4cB623e2E5"
// const BANCOR_REGISTRY = "0x178c68aefdcae5c9818e43addf6a2b66df534ed5"
// const BANCOR_ETH_WRAPPER = "0xc0829421C1d260BD3cB3E0F06cfE2D52db2cE315"
// const PLATFORM_FEE = 1000
// const STABLE_COIN_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
// const UNISWAP_FACTORY = "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
// const COMPOUND_CETHER = "0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5"
// const ONE_INCH = "0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E"
//
//
// // deploy
// module.exports = async (deployer, network, accounts) => {
//     await deployer.deploy(ParaswapParams)
//
//     await deployer.deploy(TokensTypeStorage)
//
//     await TokensTypeStorage.setTokenTypeAsOwner(STABLE_COIN_ADDRESS, "CRYPTOCURRENCY")
//
//     await deployer.deploy(GetBancorAddressFromRegistry, BANCOR_REGISTRY)
//
//     await deployer.deploy(GetRatioForBancorAssets, GetBancorAddressFromRegistry.address)
//
//     await deployer.deploy(
//       PoolPortal,
//       GetBancorAddressFromRegistry.address,
//       GetRatioForBancorAssets.address,
//       BANCOR_ETH_WRAPPER,
//       UNISWAP_FACTORY,
//       TokensTypeStorage.address
//     )
//
//     await deployer.deploy(PermittedPools, PoolPortal.address)
//
//     await deployer.deploy(PermittedStabels, STABLE_COIN_ADDRESS)
//
//     await deployer.deploy(
//       ExchangePortal,
//       PARASWAP_NETWORK_ADDRESS,
//       PARASWAP_PRICE_ADDRESS,
//       ParaswapParams.address,
//       GetBancorAddressFromRegistry.address,
//       BANCOR_ETH_WRAPPER,
//       PermittedStabels.address,
//       PoolPortal.address,
//       ONE_INCH,
//       COMPOUND_CETHER,
//       TokensTypeStorage.address
//     )
//
//     await deployer.depoy(
//       ConvertPortal,
//       ExchangePortal.address,
//       PoolPortal.address,
//       TokensTypeStorage.address,
//       COMPOUND_CETHER
//     )
//
//     await TokensTypeStorage.addNewPermittedAddress(PoolPortal.address)
//     await TokensTypeStorage.addNewPermittedAddress(ExchangePortal.address)
//
//     await deployer.deploy(PermittedExchanges, ExchangePortal.address)
//
//     await deployer.deploy(SmartFundETHFactory)
//
//     await deployer.deploy(SmartFundETHFactory)
//
//     await deployer.deploy(
//       SmartFundRegistry,
//       ConvertPortal.address,
//       PLATFORM_FEE,
//       PermittedExchanges.address,
//       ExchangePortal.address,
//       PermittedPools.address,
//       PoolPortal.address,
//       PermittedStabels.address,
//       STABLE_COIN_ADDRESS,
//       SmartFundETHFactory.address,
//       SmartFundUSDFactory.address,
//       COMPOUND_CETHER
//     )
// }
