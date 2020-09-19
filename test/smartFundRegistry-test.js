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

const SmartFundETHFactory = artifacts.require('./core/full_funds/SmartFundETHFactory.sol')
const SmartFundERC20Factory = artifacts.require('./core/full_funds/SmartFundERC20Factory.sol')

const SmartFundETHLightFactory = artifacts.require('./core/light_funds/SmartFundETHLightFactory.sol')
const SmartFundERC20LightFactory = artifacts.require('./core/light_funds/SmartFundERC20LightFactory.sol')

const SmartFundRegistry = artifacts.require('./core/SmartFundRegistry.sol')

// mock
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')


contract('SmartFundRegistry', function([userOne, userTwo, userThree]) {
  beforeEach(async function() {

    this.DAI = '0x0000000000000000000000000000000000000004'

    this.permittedAddresses = await PermittedAddresses.new(
      '0x0000000000000000000000000000000000000001',
      '0x0000000000000000000000000000000000000002',
      '0x0000000000000000000000000000000000000003',
      '0x0000000000000000000000000000000000000004'
    )

    this.COT_DAO_WALLET = await CoTraderDAOWalletMock.new()
    this.ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

    this.smartFundETHFactory = await SmartFundETHFactory.new(this.COT_DAO_WALLET.address)
    this.SmartFundERC20Factory = await SmartFundERC20Factory.new(this.COT_DAO_WALLET.address)

    this.SmartFundETHLightFactory = await SmartFundETHLightFactory.new(this.COT_DAO_WALLET.address)
    this.SmartFundERC20LightFactory = await SmartFundERC20LightFactory.new(this.COT_DAO_WALLET.address)


    this.registry = await SmartFundRegistry.new(
      '0x0000000000000000000000000000000000000001', //   ExchangePortal.address,
      '0x0000000000000000000000000000000000000002', //   PoolPortal.address,
      this.DAI,                                     //   STABLE_COIN_ADDRESS,
      '0x0000000000000000000000000000000000000000', //   COTRADER COIN ADDRESS
      this.smartFundETHFactory.address,             //   SmartFundETHFactory.address,
      this.SmartFundERC20Factory.address,           //   SmartFundERC20Factory.address
      this.SmartFundETHLightFactory.address,        //   SmartFundETHLightFactory
      this.SmartFundERC20LightFactory.address,      //   SmartFundERC20LightFactory
      '0x0000000000000000000000000000000000000003', //   Defi Portal
      this.permittedAddresses.address,              //   PermittedAddresses
    )
  })

  describe('INIT registry', function() {
    it('Correct initial registry', async function() {
      const totalFunds = await this.registry.totalSmartFunds()
      assert.equal(0, totalFunds)
    })
  })

  describe('Create full funds', function() {
    it('should be able create new ETH, USD and COT funds', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, 0, true)
      let totalFunds = await this.registry.totalSmartFunds()
      assert.equal(1, totalFunds)

      await this.registry.createSmartFund("USD Fund", 20, 1, true)
      totalFunds = await this.registry.totalSmartFunds()
      assert.equal(2, totalFunds)

      await this.registry.createSmartFund("COT Fund", 20, 2, true)
      totalFunds = await this.registry.totalSmartFunds()
      assert.equal(3, totalFunds)
    })
  })

  describe('Create ligth funds', function() {
    it('should be able create new ETH, USD and COT funds', async function() {
      await this.registry.createSmartFundLight("ETH Fund", 20, 0, true)
      let totalFunds = await this.registry.totalSmartFunds()
      assert.equal(1, totalFunds)

      await this.registry.createSmartFundLight("USD Fund", 20, 1, true)
      totalFunds = await this.registry.totalSmartFunds()
      assert.equal(2, totalFunds)

      await this.registry.createSmartFundLight("COT Fund", 20, 2, true)
      totalFunds = await this.registry.totalSmartFunds()
      assert.equal(3, totalFunds)
    })
  })

  describe('Permitted TODO', function() {
    const testAddress = '0x3710f313d52a52353181311a3584693942d30e8e'

    // it('Should not be able change non permitted exchange portal address', async function() {
    //
    // })
    //
    // it('Should be able change permitted exchange portal address', async function() {
    //
    // })
    //
    // it('Should not be able change non permitted pool portal address', async function() {
    //
    // })
    //
    // it('Should be able change permitted pool portal address', async function() {
    //
    // })
    //
    // it('Should not be able change non permitted stable portal address', async function() {
    //
    // })
    //
    // it('Should be able change permitted stable portal address', async function() {
    //
    // })
    //
    //
    // it('Not owner can not change portals addresses', async function() {
    //
    // })
    //
    // it('Not owner can not change permitted addresses', async function() {
    //
    // })
  })
})
