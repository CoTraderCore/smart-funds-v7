import { BN, fromWei } from 'web3-utils'

import ether from './helpers/ether'
import EVMRevert from './helpers/EVMRevert'
import { duration } from './helpers/duration'
import latestTime from './helpers/latestTime'
import advanceTimeAndBlock from './helpers/advanceTimeAndBlock'
const BigNumber = BN

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

// real
const PermittedAddresses = artifacts.require('./core/verification/PermittedAddresses.sol')

// Factories
const SmartFundETHFactory = artifacts.require('./core/full_funds/SmartFundETHFactory.sol')
const SmartFundERC20Factory = artifacts.require('./core/full_funds/SmartFundERC20Factory.sol')
const SmartFundETHLightFactory = artifacts.require('./core/light_funds/SmartFundETHLightFactory.sol')
const SmartFundERC20LightFactory = artifacts.require('./core/light_funds/SmartFundERC20LightFactory.sol')
// Registry
const SmartFundRegistry = artifacts.require('./core/SmartFundRegistry.sol')

// Fund abi (View portals address)
const FundABI = [
	{
		"inputs": [],
		"name": "coreFundAsset",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "defiPortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "exchangePortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "platformAddress",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "poolPortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}
]

// mock
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')


contract('SmartFundRegistry', function([userOne, userTwo, userThree]) {
  beforeEach(async function() {

    this.COT = '0x0000000000000000000000000000000000000000'
    this.ExchangePortal = '0x0000000000000000000000000000000000000001'
    this.PoolPortal = '0x0000000000000000000000000000000000000002'
    this.defiPortal = '0x0000000000000000000000000000000000000003'
    this.DAI = '0x0000000000000000000000000000000000000004'

    this.permittedAddresses = await PermittedAddresses.new(
      this.ExchangePortal,
      this.PoolPortal,
      this.defiPortal,
      this.DAI
    )

    this.COT_DAO_WALLET = await CoTraderDAOWalletMock.new()
    this.ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

    this.smartFundETHFactory = await SmartFundETHFactory.new(this.COT_DAO_WALLET.address)
    this.SmartFundERC20Factory = await SmartFundERC20Factory.new(this.COT_DAO_WALLET.address)

    this.SmartFundETHLightFactory = await SmartFundETHLightFactory.new(this.COT_DAO_WALLET.address)
    this.SmartFundERC20LightFactory = await SmartFundERC20LightFactory.new(this.COT_DAO_WALLET.address)


    this.registry = await SmartFundRegistry.new(
      this.ExchangePortal,                          //   ExchangePortal.address,
      this.PoolPortal,                              //   PoolPortal.address,
      this.DAI,                                     //   STABLE_COIN_ADDRESS,
      this.COT,                                     //   COTRADER COIN ADDRESS
      this.smartFundETHFactory.address,             //   SmartFundETHFactory.address,
      this.SmartFundERC20Factory.address,           //   SmartFundERC20Factory.address
      this.SmartFundETHLightFactory.address,        //   SmartFundETHLightFactory
      this.SmartFundERC20LightFactory.address,      //   SmartFundERC20LightFactory
      this.defiPortal,                              //   Defi Portal
      this.permittedAddresses.address,              //   PermittedAddresses
    )
  })

  describe('INIT registry', function() {
    it('Correct initial totalFunds', async function() {
      const totalFunds = await this.registry.totalSmartFunds()
      assert.equal(0, totalFunds)
    })

    it('Correct initial ExchangePortal', async function() {
      assert.equal(this.ExchangePortal, await this.registry.exchangePortalAddress())
    })

    it('Correct initial PoolPortal', async function() {
      assert.equal(this.PoolPortal, await this.registry.poolPortalAddress())
    })

    it('Correct initial DefiPortal', async function() {
      assert.equal(this.defiPortal, await this.registry.defiPortalAddress())
    })

    it('Correct initial DAI', async function() {
      assert.equal(this.DAI, await this.registry.stableCoinAddress())
    })

    it('Correct initial COT', async function() {
      assert.equal(this.COT, await this.registry.COTCoinAddress())
    })
  })

  describe('Create full funds', function() {
    it('should be able create new ETH fund and address in fund correct', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, 0, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.PoolPortal, await fund.methods.poolPortal().call())
      assert.equal(this.defiPortal, await fund.methods.defiPortal().call())
      assert.equal('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })

    it('should be able create new USD fund and address in fund correct', async function() {
      await this.registry.createSmartFund("USD Fund", 20, 1, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.PoolPortal, await fund.methods.poolPortal().call())
      assert.equal(this.defiPortal, await fund.methods.defiPortal().call())
      assert.equal(this.DAI, await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })

    it('should be able create new COT fund and address in fund correct', async function() {
      await this.registry.createSmartFund("COT Fund", 20, 2, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.PoolPortal, await fund.methods.poolPortal().call())
      assert.equal(this.defiPortal, await fund.methods.defiPortal().call())
      assert.equal(this.COT, await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })
  })

  describe('Create ligth funds', function() {
    it('should be able create new ETH fund and address in fund correct', async function() {
      await this.registry.createSmartFundLight("ETH Fund", 20, 0, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })

    it('should be able create new USD fund and address in fund correct', async function() {
      await this.registry.createSmartFundLight("USD Fund", 20, 1, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.DAI, await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })

    it('should be able create new COT fund and address in fund correct', async function() {
      await this.registry.createSmartFundLight("COT Fund", 20, 2, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.COT, await fund.methods.coreFundAsset().call())
      assert.equal(this.COT_DAO_WALLET.address, await fund.methods.platformAddress().call())
    })
  })

  describe('Should increase totalFunds after create new fund', function() {
    it('should be able create new ETH fund and address in fund correct', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, 0, true)
      assert.equal(1, await this.registry.totalSmartFunds())

      await this.registry.createSmartFund("ETH Fund 2", 20, 0, true)
      assert.equal(2, await this.registry.totalSmartFunds())

      await this.registry.createSmartFund("ETH Fund 3", 20, 0, true)
      assert.equal(3, await this.registry.totalSmartFunds())
    })

  })

  describe('Update addresses', function() {
    const testAddress = '0x0000000000000000000000000000000000000777'


    it('Owner should be able change exchange portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 1)
      await this.registry.setExchangePortalAddress(testAddress)
      assert.equal(testAddress, await this.registry.exchangePortalAddress())
    })

    it('Owner should be able change pool portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 2)
      await this.registry.setPoolPortalAddress(testAddress)
      assert.equal(testAddress, await this.registry.poolPortalAddress())
    })

    it('Owner should be able change defi portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 3)
      await this.registry.setDefiPortal(testAddress)
      assert.equal(testAddress, await this.registry.defiPortalAddress())
    })

    it('Owner should be able change stable coin address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 4)
      await this.registry.setStableCoinAddress(testAddress)
      assert.equal(testAddress, await this.registry.stableCoinAddress())
    })

    it('Owner should be able change maximumSuccessFee', async function() {
      await this.registry.setMaximumSuccessFee(4000)
      assert.equal(4000, await this.registry.maximumSuccessFee())
    })

    it('Owner should be able change ETH Factory', async function() {
      await this.registry.setNewSmartFundETHFactory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundETHFactory())
    })

    it('Owner should be able change ERC20 Factory', async function() {
      await this.registry.setNewSmartFundERC20Factory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundERC20Factory())
    })

    it('Owner should be able change ETH Factory Light', async function() {
      await this.registry.setNewSmartFundETHLightFactory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundETHLightFactory())
    })

    it('Owner should be able change ERC20 Factory Light', async function() {
      await this.registry.setNewSmartFundERC20LightFactory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundERC20LightFactory())
    })

    it('NOT Owner should NOT be able change exchange portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 1)
      await this.registry.setExchangePortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change pool portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 2)
      await this.registry.setPoolPortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change defi portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 3)
      await this.registry.setDefiPortal(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change stable coin address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 4)
      await this.registry.setStableCoinAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change maximumSuccessFee', async function() {
      await this.registry.setMaximumSuccessFee(4000, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ETH Factory', async function() {
      await this.registry.setNewSmartFundETHFactory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ERC20 Factory', async function() {
      await this.registry.setNewSmartFundERC20Factory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ETH Factory Light', async function() {
      await this.registry.setNewSmartFundETHLightFactory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ERC20 Factory Light', async function() {
      await this.registry.setNewSmartFundERC20LightFactory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })
  })
})
