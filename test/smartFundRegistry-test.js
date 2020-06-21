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
const SmartFundETHFactory = artifacts.require('./core/funds/SmartFundETHFactory.sol')
const SmartFundUSDFactory = artifacts.require('./core/funds/SmartFundUSDFactory.sol')
const SmartFundRegistry = artifacts.require('./core/SmartFundRegistry.sol')
const PermittedStables = artifacts.require('./core/verification/PermittedStables.sol')
const PermittedExchanges = artifacts.require('./core/verification/PermittedExchanges.sol')
const PermittedPools = artifacts.require('./core/verification/PermittedPools.sol')
const PermittedConverts = artifacts.require('./core/verification/PermittedConverts.sol')

// mock
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')

contract('SmartFundRegistry', function([userOne, userTwo, userThree]) {
  beforeEach(async function() {
    this.COT_DAO_WALLET = await CoTraderDAOWalletMock.new()
    this.ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

    this.smartFundETHFactory = await SmartFundETHFactory.new(this.COT_DAO_WALLET.address)
    this.smartFundUSDFactory = await SmartFundUSDFactory.new(this.COT_DAO_WALLET.address)

    this.permittedStables = await PermittedStables.new('0x0000000000000000000000000000000000000000')
    this.permittedExchanges = await PermittedExchanges.new('0x0000000000000000000000000000000000000000')
    this.permittedPools = await PermittedPools.new('0x0000000000000000000000000000000000000000')
    this.permittedConverts = await PermittedConverts.new('0x0000000000000000000000000000000000000000')

    this.registry = await SmartFundRegistry.new(
      '0x0000000000000000000000000000000000000000', //   Convert portal address
      this.permittedExchanges.address ,             //   PermittedExchanges.address,
      '0x0000000000000000000000000000000000000000', //   ExchangePortal.address,
      this.permittedPools.address ,                 //   PermittedPools.address,
      '0x0000000000000000000000000000000000000000', //   PoolPortal.address,
      this.permittedStables.address ,                //   PermittedStabels.address,
      '0x0000000000000000000000000000000000000000', //   STABLE_COIN_ADDRESS,
      this.smartFundETHFactory.address,             //   SmartFundETHFactory.address,
      this.smartFundUSDFactory.address,             //   SmartFundUSDFactory.address,
      '0x0000000000000000000000000000000000000000', //   COMPOUND_CETHER
      this.permittedConverts.address                //   Permitted converts address
    )
  })

  describe('INIT registry', function() {
    it('Correct initial registry', async function() {
      const totalFunds = await this.registry.totalSmartFunds()
      assert.equal(0, totalFunds)
    })
  })

  describe('Create funds', function() {
    it('should be able create new ETH and USD funds', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, false)
      let totalFunds = await this.registry.totalSmartFunds()
      assert.equal(1, totalFunds)

      await this.registry.createSmartFund("USD Fund", 20, true)
      totalFunds = await this.registry.totalSmartFunds()
      assert.equal(2, totalFunds)
    })
  })

  describe('Permitted', function() {
    const testAddress = '0x3710f313d52a52353181311a3584693942d30e8e'

    it('Should not be able change non permitted exchange portal address', async function() {
      await this.registry.setExchangePortalAddress(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Should be able change permitted exchange portal address', async function() {
      await this.permittedExchanges.addNewExchangeAddress(testAddress)
      await this.registry.setExchangePortalAddress(testAddress).should.be.fulfilled
    })

    it('Should not be able change non permitted pool portal address', async function() {
      await this.registry.setPoolPortalAddress(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Should be able change permitted pool portal address', async function() {
      await this.permittedPools.addNewPoolAddress(testAddress)
      await this.registry.setPoolPortalAddress(testAddress).should.be.fulfilled
    })

    it('Should not be able change non permitted stable portal address', async function() {
      await this.registry.setStableCoinAddress(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Should be able change permitted stable portal address', async function() {
      await this.permittedStables.addNewStableAddress(testAddress)
      await this.registry.setStableCoinAddress(testAddress).should.be.fulfilled
    })

    it('Should not be able change non permitted convert portal address', async function() {
      await this.registry.setConvertPortalAddress(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Should be able change permitted stable convert address', async function() {
      await this.permittedConverts.addNewConvertAddress(testAddress)
      await this.registry.setConvertPortalAddress(testAddress).should.be.fulfilled
    })

    it('Not owner can not change portals addresses', async function() {
      await this.permittedExchanges.addNewExchangeAddress(testAddress)
      await this.permittedPools.addNewPoolAddress(testAddress)
      await this.permittedStables.addNewStableAddress(testAddress)
      await this.permittedConverts.addNewConvertAddress(testAddress)

      await this.registry.setExchangePortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.registry.setPoolPortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.registry.setStableCoinAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.registry.setConvertPortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('Not owner can not change permitted addresses', async function() {
      await this.permittedExchanges.addNewExchangeAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.permittedPools.addNewPoolAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.permittedStables.addNewStableAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)

      await this.permittedConverts.addNewConvertAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })
  })
})
