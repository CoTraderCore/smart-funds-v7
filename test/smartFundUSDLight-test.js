import { BN, fromWei, toWei } from 'web3-utils'
import { MerkleTree } from 'merkletreejs'
import keccak256 from 'keccak256'
import ether from './helpers/ether'
import EVMRevert from './helpers/EVMRevert'
import { duration } from './helpers/duration'
import latestTime from './helpers/latestTime'
import advanceTimeAndBlock from './helpers/advanceTimeAndBlock'

const BigNumber = BN
const buf2hex = x => '0x'+x.toString('hex')


require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()



const ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

// Create additional mock bytes params for trade via Paraswap aggregator
const PARASWAP_MOCK_ADDITIONAL_PARAMS = web3.eth.abi.encodeParameters(
  ['uint256', 'address[]', 'uint256[]', 'uint256[]', 'uint256', 'bytes'],
  [1,
   ['0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'],
   [1,2],
   [1,2],
   1,
   "0x"
  ])

// Create additional mock bytes params for trade via 1inch aggregator
const ONEINCH_MOCK_ADDITIONAL_PARAMS = web3.eth.abi.encodeParameters(
  ['uint256', 'uint256[]'],
  [1,
   [1,1]
  ])

// real contracts
const SmartFundERC20 = artifacts.require('./core/light_funds/SmartFundERC20Light.sol')
const TokensTypeStorage = artifacts.require('./core/storage/TokensTypeStorage.sol')
const PermittedAddresses = artifacts.require('./core/verification/PermittedAddresses.sol')
const MerkleWhiteList = artifacts.require('./core/verification/MerkleTreeTokensVerification.sol')

// mock contracts
const Token = artifacts.require('./tokens/Token')
const ExchangePortalMock = artifacts.require('./portalsMock/ExchangePortalMock')
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')
const OneInch = artifacts.require('./OneInchMock')


// Tokens keys converted in bytes32
const TOKEN_KEY_CRYPTOCURRENCY = "0x43525950544f43555252454e4359000000000000000000000000000000000000"

// Contracts instance
let xxxERC,
    DAI,
    exchangePortal,
    smartFundERC20,
    BNT,
    COT_DAO_WALLET,
    yyyERC,
    tokensType,
    permittedAddresses,
    oneInch,
    merkleWhiteList,
    MerkleTREE


contract('smartFundERC20', function([userOne, userTwo, userThree]) {
  async function deployContracts(successFee=1000){
    COT_DAO_WALLET = await CoTraderDAOWalletMock.new()
    oneInch = await OneInch.new()

    // Deploy xxx Token
    xxxERC = await Token.new(
      "xxxERC20",
      "xxx",
      18,
      "1000000000000000000000000"
    )

    // Deploy yyy Token
    yyyERC = await Token.new(
      "yyyERC20",
      "yyy",
      18,
      toWei(String(100000000))
    )

    // Deploy BNT Token
    BNT = await Token.new(
      "Bancor Newtork Token",
      "BNT",
      18,
      toWei(String(100000000))
    )

    // Deploy DAI Token
    DAI = await Token.new(
      "DAI Stable Coin",
      "DAI",
      18,
      "1000000000000000000000000"
    )

    // Create MerkleTREE instance
    const leaves = [
      xxxERC.address,
      yyyERC.address,
      BNT.address,
      DAI.address,
      ETH_TOKEN_ADDRESS
    ].map(x => keccak256(x)).sort(Buffer.compare)

    MerkleTREE = new MerkleTree(leaves, keccak256)

    // Deploy merkle white list contract
    merkleWhiteList = await MerkleWhiteList.new(MerkleTREE.getRoot())

    // Deploy tokens type storage
    tokensType = await TokensTypeStorage.new()

    // Mark DAI as CRYPTOCURRENCY, because we recieve this token,
    // without trade, but via deposit
    await tokensType.setTokenTypeAsOwner(DAI.address, "CRYPTOCURRENCY")

    // Deploy exchangePortal
    exchangePortal = await ExchangePortalMock.new(
      1,
      1,
      DAI.address,
      tokensType.address,
      merkleWhiteList.address
    )

    // allow exchange portal and pool portal write to token type storage
    await tokensType.addNewPermittedAddress(exchangePortal.address)

    permittedAddresses = await PermittedAddresses.new(
      exchangePortal.address,
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000',
      DAI.address
    )

    // Deploy USD fund
    smartFundERC20 = await SmartFundERC20.new(
      '0x0000000000000000000000000000000000000000', // address _owner,
      'TEST USD FUND',                              // string _name,
      successFee,                                   // uint256 _successFee,
      COT_DAO_WALLET.address,                       // address _platformAddress,
      exchangePortal.address,                       // address _exchangePortalAddress,
      permittedAddresses.address,
      DAI.address,                                  // address_stableCoinAddress
      true                                          // verification for trade tokens
    )
  }

  beforeEach(async function() {
    await deployContracts()
  })

  describe('INIT', function() {
    it('Correct init xxx token', async function() {
      const nameX = await xxxERC.name()
      const totalSupplyX = await xxxERC.totalSupply()
      assert.equal(nameX, "xxxERC20")
      assert.equal(totalSupplyX, "1000000000000000000000000")

      const nameY = await yyyERC.name()
      const totalSupplyY = await yyyERC.totalSupply()
      assert.equal(nameY, "yyyERC20")
      assert.equal(totalSupplyY, toWei(String(100000000)))

      const nameD = await DAI.name()
      const totalSupplyD = await DAI.totalSupply()
      assert.equal(nameD, "DAI Stable Coin")
      assert.equal(totalSupplyD, "1000000000000000000000000")
    })

    it('Correct version 7', async function() {
      assert.equal(await smartFundERC20.version(), 7)
    })

    it('Correct size type', async function() {
      assert.equal(await smartFundERC20.isLightFund(), true)
    })

    it('Correct init exchange portal', async function() {
      assert.equal(await exchangePortal.stableCoinAddress(), DAI.address)
    })

    it('Correct init usd smart fund', async function() {
      const name = await smartFundERC20.name()
      const totalShares = await smartFundERC20.totalShares()
      const portalEXCHANGE = await smartFundERC20.exchangePortal()

      assert.equal(exchangePortal.address, portalEXCHANGE)
      assert.equal('TEST USD FUND', name)
      assert.equal(0, totalShares)
    })

    it('Correct init commision', async function() {
      const successFee = await smartFundERC20.successFee()
      const platformFee = await smartFundERC20.platformFee()

      assert.equal(Number(successFee), 1000)
      assert.equal(Number(platformFee), 1000)
      assert.equal(Number(successFee), Number(platformFee))
    })
  })

  describe('Deposit', function() {
    it('should not be able to deposit 0 USD', async function() {
      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(0, { from: userOne })
      .should.be.rejectedWith(EVMRevert)
    })

    it('should be able to deposit positive amount of USD', async function() {
      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })
      assert.equal(await smartFundERC20.addressToShares(userOne), toWei(String(1)))
      assert.equal(await smartFundERC20.calculateFundValue(), 100)
    })

    it('should accurately calculate empty fund value', async function() {
      // Ether is initial token, USD is second
      assert.equal((await smartFundERC20.getAllTokenAddresses()).length, 2)
      assert.equal(await smartFundERC20.calculateFundValue(), 0)
    })
  })


  describe('Profit', function() {
    it('should have zero profit before any deposits have been made', async function() {
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundERC20.calculateFundProfit(), 0)
    })

    it('should have zero profit before any trades have been made', async function() {
        await DAI.approve(smartFundERC20.address, 100, { from: userOne })
        await smartFundERC20.deposit(100, { from: userOne })
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundERC20.calculateFundProfit(), 0)
    })

    it('should accurately calculate profit if price stays stable', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await DAI.approve(smartFundERC20.address, 100, { from: userOne })
        await smartFundERC20.deposit(100, { from: userOne })

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // make a trade with the fund
        await smartFundERC20.trade(
          DAI.address,
          100,
          xxxERC.address,
          2,
          proofXXX,
          positionXXX,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // check that we still haven't made a profit
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundERC20.calculateFundProfit(), 0)
    })

    it('should accurately calculate profit upon price rise', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await DAI.approve(smartFundERC20.address, 100, { from: userOne })
        await smartFundERC20.deposit(100, { from: userOne })

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // make a trade with the fund
        await smartFundERC20.trade(
          DAI.address,
          100,
          xxxERC.address,
          2,
          proofXXX,
          positionXXX,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // change the rate (making a profit)
        await exchangePortal.setRatio(1, 2)

        // check that we have made a profit
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), 100)
        assert.equal(await smartFundERC20.calculateFundProfit(), 100)
    })

    it('should accurately calculate profit upon price fall', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await DAI.approve(smartFundERC20.address, 100, { from: userOne })
        await smartFundERC20.deposit(100, { from: userOne })

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // Trade 100 eth for 100 bat via kyber
        await smartFundERC20.trade(
          DAI.address,
          100,
          xxxERC.address,
          0,
          proofXXX,
          positionXXX,
          PARASWAP_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // change the rate to make a loss (2 tokens is 1 ether)
        await exchangePortal.setRatio(2, 1)

        // check that we made negatove profit
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), -50)
        assert.equal(await smartFundERC20.calculateFundProfit(), -50)
    })

    it('should accurately calculate profit if price stays stable with multiple trades', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, 1000)
        await yyyERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await DAI.approve(smartFundERC20.address, 100, { from: userOne })
        await smartFundERC20.deposit(100, { from: userOne })

        // get proof and position for dest token
        const proofYYY = MerkleTREE.getProof(keccak256(yyyERC.address)).map(x => buf2hex(x.data))
        const positionYYY = MerkleTREE.getProof(keccak256(yyyERC.address)).map(x => x.position === 'right' ? 1 : 0)

        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundERC20.trade(
          DAI.address,
          50,
          yyyERC.address,
          0,
          proofYYY,
          positionYYY,
          PARASWAP_MOCK_ADDITIONAL_PARAMS, 1, {
          from: userOne,
        })
        await smartFundERC20.trade(
          DAI.address,
          50,
          xxxERC.address,
          2,
          proofXXX,
          positionXXX,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1, {
          from: userOne,
        })

        // check that we still haven't made a profit
        assert.equal(await smartFundERC20.calculateFundProfit(), 0)
        assert.equal(await smartFundERC20.calculateAddressProfit(userOne), 0)
    })

    it('Fund manager should be able to withdraw after investor withdraws', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
        await DAI.transfer(exchangePortal.address, toWei(String(50)))
        await exchangePortal.pay({ from: userOne, value: toWei(String(3))})

        // deposit in fund
        await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
        await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

        assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(1)))

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundERC20.trade(
          DAI.address,
          toWei(String(1)),
          xxxERC.address,
          0,
          proofXXX,
          positionXXX,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne
          }
        )

        assert.equal((await smartFundERC20.getAllTokenAddresses()).length, 3)

        assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)

        // 1 token is now worth 2 DAI
        await exchangePortal.setRatio(1, 2)

        assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(2)))

        // get proof and position for dest token
        const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
        const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

        // should receive 200 'DAI' (wei)
        await smartFundERC20.trade(
          xxxERC.address,
          toWei(String(1)),
          DAI.address,
          0,
          proofDAI,
          positionDAI,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        assert.equal((await smartFundERC20.getAllTokenAddresses()).length, 3)

        assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(2)))

        const totalWeiDeposited = await smartFundERC20.totalWeiDeposited()
        assert.equal(fromWei(totalWeiDeposited), 1)

        // user1 now withdraws 190 DAI, 90 of which are profit
        await smartFundERC20.withdraw(0, { from: userOne })

        const totalWeiWithdrawn = await smartFundERC20.totalWeiWithdrawn()
        assert.equal(fromWei(totalWeiWithdrawn), 1.9)


        const fB = await DAI.balanceOf(smartFundERC20.address)
        assert.equal(fromWei(fB), 0.1)

        assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(0.1)))

        const {
          fundManagerRemainingCut,
          fundValue,
          fundManagerTotalCut,
        } =
        await smartFundERC20.calculateFundManagerCut()

        assert.equal(fundValue, toWei(String(0.1)))
        assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
        assert.equal(fundManagerTotalCut, toWei(String(0.1)))

          // // FM now withdraws their profit
        await smartFundERC20.fundManagerWithdraw({ from: userOne })
        // Manager, can get his 10%, and remains 0.0001996 it's  platform commision
        assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)
      })

   it('Should properly calculate profit after another user made profit and withdrew', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
        await DAI.transfer(exchangePortal.address, toWei(String(50)))
        await exchangePortal.pay({ from: userOne, value: toWei(String(5)) })
        // deposit in fund
        await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
        await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

        assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(1)))

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundERC20.trade(
          DAI.address,
          toWei(String(1)),
          xxxERC.address,
          0,
          proofXXX,
          positionXXX,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)

        // 1 token is now worth 2 ether
        await exchangePortal.setRatio(1, 2)

        assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(2)))

        // get proof and position for dest token
        const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
        const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

        // should receive 200 'ether' (wei)
        await smartFundERC20.trade(
          xxxERC.address,
          toWei(String(1)),
          DAI.address,
          0,
          proofDAI,
          positionDAI,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(2)))

        // user1 now withdraws 190 ether, 90 of which are profit
        await smartFundERC20.withdraw(0, { from: userOne })

        assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(0.1)))

        // FM now withdraws their profit
        await smartFundERC20.fundManagerWithdraw({ from: userOne })
        assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)

        // provide user2 with some DAI
        await DAI.transfer(userTwo, toWei(String(1)), { from: userOne })
        // now user2 deposits into the fund
        await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userTwo })
        await smartFundERC20.deposit(toWei(String(1)), { from: userTwo })

        // 1 token is now worth 1 ether
        await exchangePortal.setRatio(1, 1)

        await smartFundERC20.trade(
          DAI.address,
          toWei(String(1)),
          xxxERC.address,
          2,
          proofXXX,
          positionXXX,
          ONEINCH_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        // 1 token is now worth 2 ether
        await exchangePortal.setRatio(1, 2)

        // should receive 200 'ether' (wei)
        await smartFundERC20.trade(
          xxxERC.address,
          toWei(String(1)),
          DAI.address,
          0,
          proofDAI,
          positionDAI,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        const {
          fundManagerRemainingCut,
          fundValue,
          fundManagerTotalCut,
        } = await smartFundERC20.calculateFundManagerCut()

        assert.equal(fundValue, toWei(String(2)))
        // 'remains cut should be 0.1 eth'
        assert.equal(
          fundManagerRemainingCut,
          toWei(String(0.1))
        )
        // 'total cut should be 0.2 eth'
        assert.equal(
          fundManagerTotalCut,
          toWei(String(0.2))
        )
     })
  })


  describe('Withdraw', function() {
   it('should be able to withdraw all deposited funds', async function() {
      let totalShares = await smartFundERC20.totalShares()
      assert.equal(totalShares, 0)

      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })

      assert.equal(await DAI.balanceOf(smartFundERC20.address), 100)

      totalShares = await smartFundERC20.totalShares()
      assert.equal(totalShares, toWei(String(1)))

      await smartFundERC20.withdraw(0, { from: userOne })
      assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)
    })

    it('should be able to withdraw percentage of deposited funds', async function() {
      let totalShares

      totalShares = await smartFundERC20.totalShares()
      assert.equal(totalShares, 0)

      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })

      totalShares = await smartFundERC20.totalShares()

      await smartFundERC20.withdraw(5000, { from: userOne }) // 50.00%

      assert.equal(await smartFundERC20.totalShares(), totalShares / 2)
    })

    it('should be able to withdraw deposited funds with multiple users', async function() {
      // send some DAI from userOne to userTwo
      await DAI.transfer(userTwo, 100, { from: userOne })

      // deposit
      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })

      assert.equal(await smartFundERC20.calculateFundValue(), 100)

      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo })

      assert.equal(await smartFundERC20.calculateFundValue(), 200)

      // withdraw
      let sfBalance
      sfBalance = await DAI.balanceOf(smartFundERC20.address)
      assert.equal(sfBalance, 200)

      await smartFundERC20.withdraw(0,{ from: userOne })
      sfBalance = await DAI.balanceOf(smartFundERC20.address)

      assert.equal(sfBalance, 100)

      await smartFundERC20.withdraw(0, { from: userTwo })
      sfBalance = await DAI.balanceOf(smartFundERC20.address)
      assert.equal(sfBalance, 0)
    })
  })

  describe('Fund Manager', function() {
    it('should calculate fund manager and platform cut when no profits', async function() {
      await deployContracts(1500)
      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } = await smartFundERC20.calculateFundManagerCut()

      assert.equal(fundManagerRemainingCut, 0)
      assert.equal(fundValue, 0)
      assert.equal(fundManagerTotalCut, 0)
    })

    const fundManagerTest = async (expectedFundManagerCut = 15, self) => {
      // deposit
      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })
      // send XXX to exchange
      await xxxERC.transfer(exchangePortal.address, 200, { from: userOne })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      // Trade 100 DAI for 100 XXX
      await smartFundERC20.trade(
        DAI.address,
        100, xxxERC.address,
        2,
        proofXXX,
        positionXXX,
        ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
        from: userOne,
      })

      // increase price of bat. Ratio of 1/2 means 1 dai = 1/2 xxx
      await exchangePortal.setRatio(1, 2)

      // check profit and cuts are corrects
      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } = await smartFundERC20.calculateFundManagerCut()

      assert.equal(fundValue, 200)
      assert.equal(fundManagerRemainingCut.toNumber(), expectedFundManagerCut)
      assert.equal(fundManagerTotalCut.toNumber(), expectedFundManagerCut)
    }

    it('should calculate fund manager and platform cut correctly', async function() {
      await deployContracts(1500)
      await fundManagerTest()
    })

    it('should calculate fund manager and platform cut correctly when not set', async function() {
      await deployContracts(0)
      await fundManagerTest(0)
    })

    it('should calculate fund manager and platform cut correctly when no platform fee', async function() {
      await deployContracts(1500)
      await fundManagerTest(15)
    })

    it('should calculate fund manager and platform cut correctly when no success fee', async function() {
      await deployContracts(0)
      await fundManagerTest(0)
    })

    it('should be able to withdraw fund manager profits', async function() {
      await deployContracts(2000)
      await fundManagerTest(20)

      await smartFundERC20.fundManagerWithdraw({ from: userOne })

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } = await smartFundERC20.calculateFundManagerCut()

      assert.equal(fundValue, 180)
      assert.equal(fundManagerRemainingCut, 0)
      assert.equal(fundManagerTotalCut, 20)
    })
  })

  describe('Fund Manager profit cut with deposit/withdraw scenarios', function() {
    it('should accurately calculate shares when the manager makes a profit', async function() {
      // deploy smartFund with 10% success fee
      await deployContracts(1000)
      const fee = await smartFundERC20.successFee()
      assert.equal(fee, 1000)

      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(10)))

      // deposit in fund
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
      await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        xxxERC.address,
        0,
        proofXXX,
        positionXXX,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // 1 token is now worth 2 ether, the fund managers cut is now 0.1 ether
      await exchangePortal.setRatio(1, 2)

      // send some DAI to user2
      DAI.transfer(userTwo, toWei(String(1)))
      // deposit from user 2
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userTwo })
      await smartFundERC20.deposit(toWei(String(1)), { from: userTwo })

      await exchangePortal.setRatio(1, 2)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        xxxERC.address,
        0,
        proofXXX,
        positionXXX,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      await smartFundERC20.fundManagerWithdraw()

      await smartFundERC20.withdraw(0, { from: userTwo })

      const xxxUserTwo = await xxxERC.balanceOf(userTwo)

      assert.equal(fromWei(xxxUserTwo), 0.5)
    })

    it('should accurately calculate shares when FM makes a loss then breaks even', async function() {
      // deploy smartFund with 10% success fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(10)))
      await exchangePortal.pay({ from: userThree, value: toWei(String(3))})
      await DAI.transfer(exchangePortal.address, toWei(String(10)))
      // deposit in fund
      // send some DAI to user2
      DAI.transfer(userTwo, toWei(String(100)))
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userTwo })
      await smartFundERC20.deposit(toWei(String(1)), { from: userTwo })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        xxxERC.address,
        0,
        proofXXX,
        positionXXX,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // 1 token is now worth 1/2 ether, the fund lost half its value
      await exchangePortal.setRatio(2, 1)

      // send some DAI to user3
      DAI.transfer(userThree, toWei(String(100)))
      // user3 deposits, should have 2/3 of shares now
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userThree })
      await smartFundERC20.deposit(toWei(String(1)), { from: userThree })

      assert.equal(await smartFundERC20.addressToShares.call(userTwo), toWei(String(1)))
      assert.equal(await smartFundERC20.addressToShares.call(userThree), toWei(String(2)))

      // 1 token is now worth 2 ether, funds value is 3 ether
      await exchangePortal.setRatio(1, 2)

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        xxxERC.address,
        toWei(String(1)),
        DAI.address,
        2,
        proofDAI,
        positionDAI,
        ONEINCH_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      assert.equal(
        await DAI.balanceOf(smartFundERC20.address),
        toWei(String(3))
      )

      assert.equal(await smartFundERC20.calculateAddressProfit(userTwo), 0)
      assert.equal(await smartFundERC20.calculateAddressProfit(userThree), toWei(String(1)))
    })
  })

  describe('Min return', function() {
    it('Not allow execude transaction trade if for some reason DEX not sent min return asset', async function() {
      // deploy smartFund with 10% success fee
      await deployContracts(1000)
      // disable transfer in DEX
      await exchangePortal.changeStopTransferStatus(true)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(10)))

      // deposit in fund
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
      await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        xxxERC.address,
        0,
        proofXXX,
        positionXXX,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      ).should.be.rejectedWith(EVMRevert)
    })
  })

  describe('Platform cut', function() {
    it('Platform can get 10% from ETH profit', async function() {
      // deploy smartFund with 10% success fee and platform fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await exchangePortal.pay({ from: userOne, value: toWei(String(3))})

      // deposit in fund
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
      await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

      assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(1)))

      // 1 DAI now 2 ETH
      await exchangePortal.setRatio(1, 2)

      // get proof and position for dest token
      const proofETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => buf2hex(x.data))
      const positionETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        ETH_TOKEN_ADDRESS,
        0,
        proofETH,
        positionETH,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne
        }
      )

      // 1 DAI now 1 ETH
      await exchangePortal.setRatio(1, 1)

      assert.equal(await web3.eth.getBalance(smartFundERC20.address), toWei(String(2)))
      assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(2)))

      const totalWeiDeposited = await smartFundERC20.totalWeiDeposited()
      assert.equal(fromWei(totalWeiDeposited), 1)

      // user1 now withdraws 190 ether, 90 of which are profit
      await smartFundERC20.withdraw(0, { from: userOne })

      const totalWeiWithdrawn = await smartFundERC20.totalWeiWithdrawn()
      assert.equal(fromWei(totalWeiWithdrawn), 1.9)

      assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(0.1)))

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } =
      await smartFundERC20.calculateFundManagerCut()

      assert.equal(fundValue, toWei(String(0.1)))
      assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
      assert.equal(fundManagerTotalCut, toWei(String(0.1)))

      // // FM now withdraws their profit
      await smartFundERC20.fundManagerWithdraw({ from: userOne })

      // Platform get 10%
      assert.equal(fromWei(await web3.eth.getBalance(COT_DAO_WALLET.address)), 0.01)

      // Fund transfer all balance
      assert.equal(fromWei(await web3.eth.getBalance(smartFundERC20.address)), 0)
    })

    it('Platform can get 10% from ERC profit', async function() {
      // deploy smartFund with 10% success fee and platform fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
      await exchangePortal.pay({ from: userOne, value: toWei(String(3))})

      // deposit in fund
      await DAI.approve(smartFundERC20.address, toWei(String(1)), { from: userOne })
      await smartFundERC20.deposit(toWei(String(1)), { from: userOne })

      assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(1)))

      // 1 token is now cost 1 DAI
      await exchangePortal.setRatio(1, 1)

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundERC20.trade(
        DAI.address,
        toWei(String(1)),
        xxxERC.address,
        2,
        proofXXX,
        positionXXX,
        ONEINCH_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne
        }
      )

      assert.equal(await DAI.balanceOf(smartFundERC20.address), 0)

      assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(1)))

      // 1 token is now worth 2 DAI
      await exchangePortal.setRatio(1, 2)

      assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(2)))

      assert.equal(await DAI.balanceOf(smartFundERC20.address), toWei(String(0)))
      assert.equal(await xxxERC.balanceOf(smartFundERC20.address), toWei(String(1)))

      const totalWeiDeposited = await smartFundERC20.totalWeiDeposited()
      assert.equal(fromWei(totalWeiDeposited), 1)

      // user1 now withdraws 190 ether, 90 of which are profit
      await smartFundERC20.withdraw(0, { from: userOne })

      const totalWeiWithdrawn = await smartFundERC20.totalWeiWithdrawn()
      assert.equal(fromWei(totalWeiWithdrawn), 1.9)

      assert.equal(await smartFundERC20.calculateFundValue(), toWei(String(0.1)))

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } =
      await smartFundERC20.calculateFundManagerCut()

      assert.equal(fundValue, toWei(String(0.1)))
      assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
      assert.equal(fundManagerTotalCut, toWei(String(0.1)))

      // // FM now withdraws their profit
      await smartFundERC20.fundManagerWithdraw({ from: userOne })

      // Platform get 10%
      // 0.005 xxx = 0.01 ETH
      assert.equal(fromWei(await xxxERC.balanceOf(COT_DAO_WALLET.address)), 0.005)

      // Fund transfer all balance
      assert.equal(fromWei(await xxxERC.balanceOf(smartFundERC20.address)), 0)
    })
  })

  describe('ERC20 implementation', function() {
    it('should be able to transfer shares to another user', async function() {
      // send some DAI to user two
      DAI.transfer(userTwo, 100)

      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo })

      assert.equal(await smartFundERC20.balanceOf(userTwo), toWei(String(1)))

      await smartFundERC20.transfer(userThree, toWei(String(1)), { from: userTwo })
      assert.equal(await smartFundERC20.balanceOf(userThree), toWei(String(1)))
      assert.equal(await smartFundERC20.balanceOf(userTwo), 0)
    })

    it('should allow a user to withdraw their shares that were transfered to them', async function() {
      // send some DAI to user two
      DAI.transfer(userTwo, 1000)
      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo })
      await smartFundERC20.transfer(userThree, toWei(String(1)), { from: userTwo })
      assert.equal(await smartFundERC20.balanceOf(userThree), toWei(String(1)))
      await smartFundERC20.withdraw(0, { from: userThree })
      assert.equal(await smartFundERC20.balanceOf(userThree), 0)
    })
  })

  describe('Whitelist Investors', function() {
    it('should not allow anyone to deposit when whitelist is empty and set', async function() {
      // send some DAI to user two
      DAI.transfer(userTwo, 1000)

      await smartFundERC20.setWhitelistOnly(true)
      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne }).should.be.rejectedWith(EVMRevert)
      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo }).should.be.rejectedWith(EVMRevert)
    })


    it('should only allow whitelisted addresses to deposit', async function() {
      // send some DAI to user two
      DAI.transfer(userTwo, 1000)

      await smartFundERC20.setWhitelistOnly(true)
      await smartFundERC20.setWhitelistAddress(userOne, true)

      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })

      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo }).should.be.rejectedWith(EVMRevert)

      await smartFundERC20.setWhitelistAddress(userTwo, true)

      await DAI.approve(smartFundERC20.address, 100, { from: userTwo })
      await smartFundERC20.deposit(100, { from: userTwo })

      assert.equal(await smartFundERC20.addressToShares.call(userOne), toWei(String(1)))
      assert.equal(await smartFundERC20.addressToShares.call(userTwo), toWei(String(1)))

      await smartFundERC20.setWhitelistAddress(userOne, false)

      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne }).should.be.rejectedWith(EVMRevert)

      await smartFundERC20.setWhitelistOnly(false)

      await DAI.approve(smartFundERC20.address, 100, { from: userOne })
      await smartFundERC20.deposit(100, { from: userOne })

      assert.equal(await smartFundERC20.addressToShares.call(userOne), toWei(String(2)))
    })
  })


  describe('Update addresses', function() {
    const testAddress = '0x0000000000000000000000000000000000000777'

    // exchange portal
    it('Owner should not be able change NON permitted exchane portal', async function() {
      await smartFundERC20.setNewExchangePortal(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Owner should be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 1)
      await smartFundERC20.setNewExchangePortal(testAddress)
      assert.equal(testAddress, await smartFundERC20.exchangePortal())
    })

    it('NOT Owner should NOT be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 1)
      await smartFundERC20.setNewExchangePortal(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })
  })
  // END
})
