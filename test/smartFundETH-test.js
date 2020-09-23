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
const SmartFundETH = artifacts.require('./core/full_funds/SmartFundETH.sol')
const TokensTypeStorage = artifacts.require('./core/storage/TokensTypeStorage.sol')
const PermittedAddresses = artifacts.require('./core/verification/PermittedAddresses.sol')
const MerkleWhiteList = artifacts.require('./core/verification/MerkleTreeTokensVerification.sol')
const DefiPortal = artifacts.require('./core/portals/DefiPortal.sol')

// mock
const YVault = artifacts.require('./tokens/YVaultMock.sol')
const Token = artifacts.require('./tokens/Token')
const ExchangePortalMock = artifacts.require('./portalsMock/ExchangePortalMock')
const PoolPortalMock = artifacts.require('./portalsMock/PoolPortalMock')
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')
const OneInch = artifacts.require('./OneInchMock')


// Tokens keys converted in bytes32
const TOKEN_KEY_CRYPTOCURRENCY = "0x43525950544f43555252454e4359000000000000000000000000000000000000"
const TOKEN_KEY_BANCOR_POOL = "0x42414e434f525f41535345540000000000000000000000000000000000000000"
const TOKEN_KEY_UNISWAP_POOL = "0x554e49535741505f504f4f4c0000000000000000000000000000000000000000"

// Contracts instance
let xxxERC,
    DAI,
    exchangePortal,
    smartFundETH,
    BNT,
    DAIUNI,
    DAIBNT,
    poolPortal,
    COT_DAO_WALLET,
    yyyERC,
    tokensType,
    permittedAddresses,
    oneInch,
    merkleWhiteList,
    MerkleTREE,
    defiPortal,
    yDAI,
    ETHBNT



contract('SmartFundETH', function([userOne, userTwo, userThree]) {

  async function deployContracts(successFee=1000){
    COT_DAO_WALLET = await CoTraderDAOWalletMock.new()
    oneInch = await OneInch.new()

    // DEPLOY ERC20 TOKENS
    xxxERC = await Token.new(
      "xxxERC20",
      "xxx",
      18,
      toWei(String(100000000))
    )

    yyyERC = await Token.new(
      "yyyERC20",
      "yyy",
      18,
      toWei(String(100000000))
    )

    BNT = await Token.new(
      "Bancor Newtork Token",
      "BNT",
      18,
      toWei(String(100000000))
    )

    DAIBNT = await Token.new(
      "DAI Bancor",
      "DAIBNT",
      18,
      toWei(String(100000000))
    )

    DAIUNI = await Token.new(
      "DAI Uniswap",
      "DAIUNI",
      18,
      toWei(String(100000000))
    )

    DAI = await Token.new(
      "DAI Stable Coin",
      "DAI",
      18,
      toWei(String(100000000))
    )

    // Yearn token
    yDAI = await YVault.new(
      "Y Vault Yeran Token",
      "yVault",
      18,
      DAI.address
    )

    ETHBNT = await Token.new(
      "ETH Bancor",
      "ETHBNT",
      18,
      toWei(String(100000000))
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

    // Mark ETH as CRYPTOCURRENCY, because we recieve this token,
    // without trade, but via deposit
    await tokensType.setTokenTypeAsOwner(ETH_TOKEN_ADDRESS, "CRYPTOCURRENCY")

    defiPortal = await DefiPortal.new(tokensType.address)

    // Deploy exchangePortal
    exchangePortal = await ExchangePortalMock.new(
      1,
      1,
      DAI.address,
      tokensType.address,
      merkleWhiteList.address
    )

    // Depoy poolPortal
    poolPortal = await PoolPortalMock.new(
      BNT.address,
      DAI.address,
      DAIBNT.address,
      DAIUNI.address,
      ETHBNT.address,
      tokensType.address
    )

    // allow exchange portal and pool portal write to token type storage
    await tokensType.addNewPermittedAddress(exchangePortal.address)
    await tokensType.addNewPermittedAddress(poolPortal.address)
    await tokensType.addNewPermittedAddress(defiPortal.address)

    permittedAddresses = await PermittedAddresses.new(
      exchangePortal.address,
      poolPortal.address,
      defiPortal.address,
      DAI.address
    )

    // Deploy ETH fund
    smartFundETH = await SmartFundETH.new(
      userOne,                                      // address _owner,
      'TEST ETH FUND',                              // string _name,
      successFee,                                   // uint256 _successFee,
      COT_DAO_WALLET.address,                       // address _platformAddress,
      exchangePortal.address,                       // address _exchangePortalAddress,
      poolPortal.address,                           // address _poolPortalAddress,
      defiPortal.address,
      permittedAddresses.address,
      true                                          // verification for trade tokens
    )

    // send all BNT and UNI pools to portal
    DAIBNT.transfer(poolPortal.address, toWei(String(100000000)))
    DAIUNI.transfer(poolPortal.address, toWei(String(100000000)))
    ETHBNT.transfer(poolPortal.address, toWei(String(100000000)))
  }

  beforeEach(async function() {
    await deployContracts()
  })

  describe('INIT', function() {
    it('Correct init tokens', async function() {
      const nameX = await xxxERC.name()
      const totalSupplyX = await xxxERC.totalSupply()
      assert.equal(nameX, "xxxERC20")
      assert.equal(totalSupplyX, toWei(String(100000000)))

      const nameY = await yyyERC.name()
      const totalSupplyY = await yyyERC.totalSupply()
      assert.equal(nameY, "yyyERC20")
      assert.equal(totalSupplyY, toWei(String(100000000)))

      const nameDB = await DAIBNT.name()
      const totalSupplyDB = await DAIBNT.totalSupply()
      assert.equal(nameDB, "DAI Bancor")
      assert.equal(totalSupplyDB, toWei(String(100000000)))

      const nameDU = await DAIUNI.name()
      const totalSupplyDU = await DAIUNI.totalSupply()
      assert.equal(nameDU, "DAI Uniswap")
      assert.equal(totalSupplyDU, toWei(String(100000000)))

    })

    it('Correct version 7', async function() {
      assert.equal(await smartFundETH.version(), 7)
    })

    it('Correct size type', async function() {
      assert.equal(await smartFundETH.isLightFund(), false)
    })

    it('Correct exchange portal in fund', async function() {
      assert.equal(await smartFundETH.exchangePortal(), exchangePortal.address)
    })

    it('Correct defi portal in fund', async function() {
      assert.equal(await smartFundETH.defiPortal(), defiPortal.address)
    })

    it('Correct pool portal in fund', async function() {
      assert.equal(await smartFundETH.poolPortal(), poolPortal.address)
    })

    it('Correct init exchange portal stable coin', async function() {
      assert.equal(await exchangePortal.stableCoinAddress(), DAI.address)
    })

    it('Correct init defi portal version', async function() {
      assert.equal(await defiPortal.version(), 4)
    })

    it('Correct init pool portal', async function() {
      const DAIUNIBNTAddress = await poolPortal.DAIUNIPoolToken()
      const DAIBNTBNTAddress = await poolPortal.DAIBNTPoolToken()
      const BNTAddress = await poolPortal.BNT()
      const DAIAddress = await poolPortal.DAI()

      assert.equal(DAIUNIBNTAddress, DAIUNI.address)
      assert.equal(DAIBNTBNTAddress, DAIBNT.address)
      assert.equal(BNTAddress, BNT.address)
      assert.equal(DAIAddress, DAI.address)

      assert.equal(await DAIUNI.balanceOf(poolPortal.address), toWei(String(100000000)))
      assert.equal(await DAIBNT.balanceOf(poolPortal.address), toWei(String(100000000)))
    })

    it('Correct init eth smart fund', async function() {
      const name = await smartFundETH.name()
      const totalShares = await smartFundETH.totalShares()
      const portalEXCHANGE = await smartFundETH.exchangePortal()
      const portalPOOL = await smartFundETH.poolPortal()

      assert.equal(exchangePortal.address, portalEXCHANGE)
      assert.equal(poolPortal.address, portalPOOL)
      assert.equal('TEST ETH FUND', name)
      assert.equal(0, totalShares)
    })

    it('Correct init commision', async function() {
      const successFee = await smartFundETH.successFee()
      const platformFee = await smartFundETH.platformFee()

      assert.equal(Number(successFee), 1000)
      assert.equal(Number(platformFee), 1000)
      assert.equal(Number(successFee), Number(platformFee))
    })
  })

  describe('Deposit', function() {
    it('should not be able to deposit 0 Ether', async function() {
      await smartFundETH.deposit({ from: userOne, value: 0 })
      .should.be.rejectedWith(EVMRevert)
    })

    it('should be able to deposit positive amount of Ether', async function() {
      await smartFundETH.deposit({ from: userOne, value: 100 })
      assert.equal(await smartFundETH.addressToShares(userOne), toWei(String(1)))
      assert.equal(await smartFundETH.calculateFundValue(), 100)
    })

    it('should accurately calculate empty fund value', async function() {
      assert.equal((await smartFundETH.getAllTokenAddresses()).length, 1) // Ether is initial token
      assert.equal(await smartFundETH.calculateFundValue(), 0)
    })
  })

  describe('Profit', function() {
    it('should have zero profit before any deposits have been made', async function() {
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundETH.calculateFundProfit(), 0)
    })

    it('should have zero profit before any trades have been made', async function() {
        await smartFundETH.deposit({ from: userOne, value: 100 })
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundETH.calculateFundProfit(), 0)
    })

    it('should accurately calculate profit if price stays stable', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: 100 })

        // get proof and position for dest token
        const proof = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const position = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // make a trade with the fund
        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS, 100,
          xxxERC.address,
          2,
          proof,
          position,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // check that we still haven't made a profit
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), 0)
        assert.equal(await smartFundETH.calculateFundProfit(), 0)
    })

    it('should accurately calculate profit upon price rise', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: 100 })

        // get proof and position for dest token
        const proof = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const position = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // make a trade with the fund
        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
          100,
          xxxERC.address,
          0,
          proof,
          position,
          PARASWAP_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // change the rate (making a profit)
        await exchangePortal.setRatio(1, 2)

        // check that we have made a profit
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), 100)
        assert.equal(await smartFundETH.calculateFundProfit(), 100)
    })

    it('should accurately calculate profit upon price fall', async function() {
        // give portal some money
        await xxxERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: 100 })

        // get proof and position for dest token
        const proof = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const position = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        // Trade 100 eth for 100 bat via kyber
        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
          100,
          xxxERC.address,
          2,
          proof,
          position,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // change the rate to make a loss (2 tokens is 1 ether)
        await exchangePortal.setRatio(2, 1)

        // check that we made negatove profit
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), -50)
        assert.equal(await smartFundETH.calculateFundProfit(), -50)
    })

    it('should accurately calculate profit if price stays stable with multiple trades', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, 1000)
        await yyyERC.transfer(exchangePortal.address, 1000)

        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: 100 })

        // get proof and position for dest token
        const proofYYY = MerkleTREE.getProof(keccak256(yyyERC.address)).map(x => buf2hex(x.data))
        const positionYYY = MerkleTREE.getProof(keccak256(yyyERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
          50,
          yyyERC.address,
          0,
          proofYYY,
          positionYYY,
          PARASWAP_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS, 50,
          xxxERC.address,
          2,
          proofXXX,
          positionXXX,
          ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
          from: userOne,
        })

        // check that we still haven't made a profit
        assert.equal(await smartFundETH.calculateFundProfit(), 0)
        assert.equal(await smartFundETH.calculateAddressProfit(userOne), 0)
    })

    it('Fund manager should be able to withdraw after investor withdraws', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
        await exchangePortal.pay({ from: userOne, value: toWei(String(3))})
        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

        assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
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

        assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)

        // 1 token is now worth 2 ether
        await exchangePortal.setRatio(1, 2)

        assert.equal(await smartFundETH.calculateFundValue(), toWei(String(2)))

        // get proof and position for dest token
        const proofETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => buf2hex(x.data))
        const positionETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => x.position === 'right' ? 1 : 0)

        // should receive 200 'ether' (wei)
        await smartFundETH.trade(
          xxxERC.address,
          toWei(String(1)),
          ETH_TOKEN_ADDRESS,
          0,
          proofETH,
          positionETH,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(2)))

        const totalWeiDeposited = await smartFundETH.totalWeiDeposited()
        assert.equal(fromWei(totalWeiDeposited), 1)

        // user1 now withdraws 190 ether, 90 of which are profit
        await smartFundETH.withdraw(0, { from: userOne })

        const totalWeiWithdrawn = await smartFundETH.totalWeiWithdrawn()
        assert.equal(fromWei(totalWeiWithdrawn), 1.9)

        assert.equal(await smartFundETH.calculateFundValue(), toWei(String(0.1)))

        const {
          fundManagerRemainingCut,
          fundValue,
          fundManagerTotalCut,
        } =
        await smartFundETH.calculateFundManagerCut()

        assert.equal(fundValue, toWei(String(0.1)))
        assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
        assert.equal(fundManagerTotalCut, toWei(String(0.1)))

          // // FM now withdraws their profit
        await smartFundETH.fundManagerWithdraw({ from: userOne })
        // Manager, can get his 10%, and remains 0.0001996 it's  platform commision
        assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)
      })

   it('Should properly calculate profit after another user made profit and withdrew', async function() {
        // give exchange portal contract some money
        await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
        await exchangePortal.pay({ from: userOne, value: toWei(String(5)) })
        // deposit in fund
        await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

        assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

        // get proof and position for dest token
        const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
        const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
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

        assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)

        // 1 token is now worth 2 ether
        await exchangePortal.setRatio(1, 2)

        assert.equal(await smartFundETH.calculateFundValue(), toWei(String(2)))

        // get proof and position for dest token
        const proofETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => buf2hex(x.data))
        const positionETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => x.position === 'right' ? 1 : 0)

        // should receive 200 'ether' (wei)
        await smartFundETH.trade(
          xxxERC.address,
          toWei(String(1)),
          ETH_TOKEN_ADDRESS,
          0,
          proofETH,
          positionETH,
          PARASWAP_MOCK_ADDITIONAL_PARAMS,
          1,
          {
            from: userOne,
          }
        )

        assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(2)))

        // user1 now withdraws 190 ether, 90 of which are profit
        await smartFundETH.withdraw(0, { from: userOne })

        assert.equal(await smartFundETH.calculateFundValue(), toWei(String(0.1)))

        // FM now withdraws their profit
        await smartFundETH.fundManagerWithdraw({ from: userOne })
        assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)

        // now user2 deposits into the fund
        await smartFundETH.deposit({ from: userTwo, value: toWei(String(1)) })

        // 1 token is now worth 1 ether
        await exchangePortal.setRatio(1, 1)

        await smartFundETH.trade(
          ETH_TOKEN_ADDRESS,
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

        // 1 token is now worth 2 ether
        await exchangePortal.setRatio(1, 2)

        // should receive 200 'ether' (wei)
        await smartFundETH.trade(
          xxxERC.address,
          toWei(String(1)),
          ETH_TOKEN_ADDRESS,
          0,
          proofETH,
          positionETH,
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
        } = await smartFundETH.calculateFundManagerCut()

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
      const totalShares = await smartFundETH.totalShares()
      assert.equal(totalShares, 0)

      await smartFundETH.deposit({ from: userOne, value: 100 })
      assert.equal(await web3.eth.getBalance(smartFundETH.address), 100)
      await smartFundETH.withdraw(0, { from: userOne })
      assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)
    })

    it('should be able to withdraw percentage of deposited funds', async function() {
      let totalShares

      totalShares = await smartFundETH.totalShares()
      assert.equal(totalShares, 0)

      await smartFundETH.deposit({ from: userOne, value: 100 })

      totalShares = await smartFundETH.totalShares()

      await smartFundETH.withdraw(5000, { from: userOne }) // 50.00%

      assert.equal(await smartFundETH.totalShares(), totalShares / 2)
    })

    it('should be able to withdraw deposited funds with multiple users', async function() {
      // deposit
      await smartFundETH.deposit({ from: userOne, value: 100 })

      assert.equal(await smartFundETH.calculateFundValue(), 100)
      await smartFundETH.deposit({ from: userTwo, value: 100 })
      assert.equal(await smartFundETH.calculateFundValue(), 200)

      // withdraw
      let sfBalance
      sfBalance = await web3.eth.getBalance(smartFundETH.address)
      assert.equal(sfBalance, 200)

      await smartFundETH.withdraw(0, { from: userOne })
      sfBalance = await web3.eth.getBalance(smartFundETH.address)

      assert.equal(sfBalance, 100)

      await smartFundETH.withdraw(0, { from: userTwo })
      sfBalance = await web3.eth.getBalance(smartFundETH.address)
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
      } = await smartFundETH.calculateFundManagerCut()

      assert.equal(fundManagerRemainingCut, 0)
      assert.equal(fundValue, 0)
      assert.equal(fundManagerTotalCut, 0)
    })

    const fundManagerTest = async (expectedFundManagerCut = 15, self) => {
      // deposit
      await smartFundETH.deposit({ from: userOne, value: 100 })
      // send xxx to exchange
      await xxxERC.transfer(exchangePortal.address, 200, { from: userOne })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      // Trade 100 ether for 100 xxx
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        100,
        xxxERC.address,
        2,
        proofXXX,
        positionXXX,
        ONEINCH_MOCK_ADDITIONAL_PARAMS, 1,{
        from: userOne,
      })

      // increase price of xxx. Ratio of 1/2 means 1 eth = 1/2 xxx
      await exchangePortal.setRatio(1, 2)

      // check profit and cuts are corrects
      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } = await smartFundETH.calculateFundManagerCut()

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

      await smartFundETH.fundManagerWithdraw({ from: userOne })

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } = await smartFundETH.calculateFundManagerCut()

      assert.equal(fundValue, 180)
      assert.equal(fundManagerRemainingCut, 0)
      assert.equal(fundManagerTotalCut, 20)
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
      await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(1)),
        xxxERC.address,
        0,
        proofXXX,
        positionXXX,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        toWei(String(1)),
        {
          from: userOne,
        }
      ).should.be.rejectedWith(EVMRevert)
    })
  })

  describe('Fund Manager profit cut with deposit/withdraw scenarios', function() {
    it('should accurately calculate shares when the manager makes a profit', async function() {
      // deploy smartFund with 10% success fee
      await deployContracts(1000)
      const fee = await smartFundETH.successFee()
      assert.equal(fee, 1000)


      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(10)))

      // deposit in fund
      await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      // After trade via aggregatos recieved asset should be marked as CRYPTOCURRENCY
      assert.equal(await tokensType.getType(xxxERC.address), TOKEN_KEY_CRYPTOCURRENCY)

      // 1 token is now worth 2 ether, the fund managers cut is now 0.1 ether
      await exchangePortal.setRatio(1, 2)

      await smartFundETH.deposit({ from: userTwo, value: toWei(String(1)) })

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      await smartFundETH.fundManagerWithdraw()

      await smartFundETH.withdraw(0,{ from: userTwo })

      const xxxUserTwo = await xxxERC.balanceOf(userTwo)

      assert.equal(fromWei(xxxUserTwo), 0.5)
    })

    it('should accurately calculate shares when FM makes a loss then breaks even', async function() {
      // deploy smartFund with 10% success fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(10)))
      await exchangePortal.pay({ from: userThree, value: toWei(String(3))})

      // deposit in fund
      await smartFundETH.deposit({ from: userTwo, value: toWei(String(1)) })

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      // user3 deposits, should have 2/3 of shares now
      await smartFundETH.deposit({ from: userThree, value: toWei(String(1)) })

      assert.equal(await smartFundETH.addressToShares.call(userTwo), toWei(String(1)))
      assert.equal(await smartFundETH.addressToShares.call(userThree), toWei(String(2)))

      // 1 token is now worth 2 ether, funds value is 3 ether
      await exchangePortal.setRatio(1, 2)

      // get proof and position for dest token
      const proofETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => buf2hex(x.data))
      const positionETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        xxxERC.address,
        toWei(String(1)),
        ETH_TOKEN_ADDRESS,
        0,
        proofETH,
        positionETH,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      assert.equal(
        await web3.eth.getBalance(smartFundETH.address),
        toWei(String(3))
      )

      assert.equal(await smartFundETH.calculateAddressProfit(userTwo), 0)
      assert.equal(await smartFundETH.calculateAddressProfit(userThree), toWei(String(1)))
    })
  })

  describe('BUY/SELL YEARN Finance', function() {
    it('should be able buy/sell Yearn yDAI token', async function() {
      // send some assets to pool portal
      await DAI.transfer(exchangePortal.address, toWei(String(1)))
      await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 DAI from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      // Check balance before buy yDAI
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await yDAI.balanceOf(smartFundETH.address), 0)

      const tokenAddressBefore = await smartFundETH.getAllTokenAddresses()

      // BUY yDAI
      await smartFundETH.callDefiPortal(
        [DAI.address],
        [toWei(String(1))],
        ["0x0000000000000000000000000000000000000000000000000000000000000000"],
        web3.eth.abi.encodeParameters(
         ['address', 'uint256'],
         [yDAI.address, toWei(String(1))]
        )
      ).should.be.fulfilled

      const tokenAddressAfter = await smartFundETH.getAllTokenAddresses()

      // yDAI shoul be added in fund
      assert.isTrue(tokenAddressAfter.length > tokenAddressBefore.length)

      // Check balance after buy yDAI
      assert.equal(fromWei(await DAI.balanceOf(smartFundETH.address)), 0)
      assert.equal(await yDAI.balanceOf(smartFundETH.address), toWei(String(1)))

      // SELL yDAI
      await smartFundETH.callDefiPortal(
        [yDAI.address],
        [toWei(String(1))],
        ["0x0000000000000000000000000000000000000000000000000000000000000001"],
        web3.eth.abi.encodeParameters(
         ['uint256'],
         [toWei(String(1))]
        )
      ).should.be.fulfilled

      // Check balance after sell yDAI
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await yDAI.balanceOf(smartFundETH.address), 0)
    })
  })


  describe('UNISWAP and BANCOR pools', function() {
    it('should be able buy/sell Bancor pool', async function() {
      // send some assets to pool portal
      await BNT.transfer(exchangePortal.address, toWei(String(1)))
      await DAI.transfer(exchangePortal.address, toWei(String(1)))

      await smartFundETH.deposit({ from: userOne, value: toWei(String(2)) })

      // get proof and position for dest token
      const proofBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => buf2hex(x.data))
      const positionBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 BNT from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(1)),
        BNT.address,
        0,
        proofBNT,
        positionBNT,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 DAI from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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
      // Check balance before buy pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAIBNT.balanceOf(smartFundETH.address), 0)

      // get pool addresses and connectors
      const { connectorsAddress, connectorsAmount } = await poolPortal.getDataForBuyingPool(
        DAIBNT.address,
        0,
        toWei(String(2)))

      // buy BNT pool
      await smartFundETH.buyPool(toWei(String(2)), 0, DAIBNT.address, connectorsAddress, connectorsAmount, [], "0x")
      // after buy BNT pool recieved asset should be marked as BANCOR POOL
      assert.equal(await tokensType.getType(DAIBNT.address), TOKEN_KEY_BANCOR_POOL)

      // Check balance after buy pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), 0)
      assert.equal(await DAI.balanceOf(smartFundETH.address), 0)
      assert.equal(await DAIBNT.balanceOf(smartFundETH.address), toWei(String(2)))

      // sell pool
      await smartFundETH.sellPool(toWei(String(2)), 0, DAIBNT.address, [], "0x")

      // Check balance after sell pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAIBNT.balanceOf(smartFundETH.address), 0)

    })

    it('should be able buy/sell Bancor pool with ETH Connector', async function() {
      // send some assets to pool portal
      await BNT.transfer(exchangePortal.address, toWei(String(1)))

      await smartFundETH.deposit({ from: userOne, value: toWei(String(2)) })

      // get proof and position for dest token
      const proofBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => buf2hex(x.data))
      const positionBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 BNT from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(1)),
        BNT.address,
        0,
        proofBNT,
        positionBNT,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // Check balance before buy pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await ETHBNT.balanceOf(smartFundETH.address), 0)

      const connectorsAddress = ["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", BNT.address]
      const connectorsAmount = [toWei(String(1)), toWei(String(1))]

      // buy BNT pool
      await smartFundETH.buyPool(toWei(String(2)), 0, ETHBNT.address, connectorsAddress, connectorsAmount, [], "0x")
      // after buy BNT pool recieved asset should be marked as BANCOR POOL
      assert.equal(await tokensType.getType(ETHBNT.address), TOKEN_KEY_BANCOR_POOL)

      // Check balance after buy pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), 0)
      assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)
      assert.equal(await ETHBNT.balanceOf(smartFundETH.address), toWei(String(2)))

      // sell pool
      await smartFundETH.sellPool(toWei(String(2)), 0, ETHBNT.address, [], "0x")

      // Check balance after sell pool
      assert.equal(await BNT.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))
      assert.equal(await ETHBNT.balanceOf(smartFundETH.address), 0)
    })

    it('should be able buy/sell Uniswap pool', async function() {
      // send some assets to pool portal
      await DAI.transfer(exchangePortal.address, toWei(String(1)))

      await smartFundETH.deposit({ from: userOne, value: toWei(String(2)) })

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 DAI from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      // Check balance before buy pool
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAIUNI.balanceOf(smartFundETH.address), 0)

      // get pool addresses and connectors
      const { connectorsAddress, connectorsAmount } = await poolPortal.getDataForBuyingPool(
        DAIUNI.address,
        1,
        toWei(String(1)))

      // Buy UNI Pool
      await smartFundETH.buyPool(toWei(String(1)), 1, DAIUNI.address, connectorsAddress, connectorsAmount, [], "0x")
      // After buy UNI pool recieved asset should be marked as UNI POOL
      assert.equal(await tokensType.getType(DAIUNI.address), TOKEN_KEY_UNISWAP_POOL)

      // Check balance after buy pool
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(0)))
      assert.equal(await DAIUNI.balanceOf(smartFundETH.address), toWei(String(2)))
      const fundETHBalanceAfterBuy = await web3.eth.getBalance(smartFundETH.address)

      // Sell UNI Pool
      await smartFundETH.sellPool(toWei(String(2)), 1, DAIUNI.address, [], "0x")

      // Check balance after buy pool
      const fundETHBalanceAfterSell = await web3.eth.getBalance(smartFundETH.address)
      assert.equal(await DAI.balanceOf(smartFundETH.address), toWei(String(1)))
      assert.equal(await DAIUNI.balanceOf(smartFundETH.address), toWei(String(0)))

      assert.isTrue(fundETHBalanceAfterSell > fundETHBalanceAfterBuy)
    })

    it('Take into account UNI and BNT pools in fund value', async function() {
      // send some assets to pool portal
      await BNT.transfer(exchangePortal.address, toWei(String(1)))
      await DAI.transfer(exchangePortal.address, toWei(String(2)))

      await smartFundETH.deposit({ from: userOne, value: toWei(String(4)) })

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 2 DAI from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(2)),
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


      // get 1 BNT from exchange portal

      // get proof and position for dest token
      const proofBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => buf2hex(x.data))
      const positionBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(1)),
        BNT.address,
        0,
        proofBNT,
        positionBNT,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // get UNI pool addresses and connectors
      const { connectorsAddress:connectorsAddressUNI, connectorsAmount:connectorsAmountUNI } = await poolPortal.getDataForBuyingPool(
        DAIUNI.address,
        1,
        toWei(String(1)))

      // Buy UNI Pool
      await smartFundETH.buyPool(toWei(String(1)), 1, DAIUNI.address, connectorsAddressUNI, connectorsAmountUNI, [], "0x")

      // get BNT pool addresses and connectors
      const { connectorsAddress:connectorsAddressBNT, connectorsAmount:connectorsAmountBNT } = await poolPortal.getDataForBuyingPool(
        DAIBNT.address,
        0,
        toWei(String(2)))

      // Buy BNT Pool
      await smartFundETH.buyPool(toWei(String(2)), 0, DAIBNT.address, connectorsAddressBNT, connectorsAmountBNT, [], "0x")

      // Fund get UNI and BNT Pools
      assert.equal(await DAIBNT.balanceOf(smartFundETH.address), toWei(String(2)))
      assert.equal(await DAIUNI.balanceOf(smartFundETH.address), toWei(String(2)))

      // Assume that asset prices have not changed, and therefore the value of the fund
      // should be the same as with the first deposit
      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(4)))
    })

    it('Investor can withdraw UNI and BNT pools', async function() {
      // send some assets to pool portal
      await BNT.transfer(exchangePortal.address, toWei(String(1)))
      await DAI.transfer(exchangePortal.address, toWei(String(2)))

      await smartFundETH.deposit({ from: userOne, value: toWei(String(4)) })

      // get proof and position for dest token
      const proofDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => buf2hex(x.data))
      const positionDAI = MerkleTREE.getProof(keccak256(DAI.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 2 DAI from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(2)),
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

      // get proof and position for dest token
      const proofBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => buf2hex(x.data))
      const positionBNT = MerkleTREE.getProof(keccak256(BNT.address)).map(x => x.position === 'right' ? 1 : 0)

      // get 1 BNT from exchange portal
      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
        toWei(String(1)),
        BNT.address,
        0,
        proofBNT,
        positionBNT,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      // get UNI pool addresses and connectors
      const {
        connectorsAddress:connectorsAddressUNI,
        connectorsAmount:connectorsAmountUNI
      } = await poolPortal.getDataForBuyingPool(
        DAIUNI.address,
        1,
        toWei(String(1)))

      // Buy UNI Pool
      await smartFundETH.buyPool(toWei(String(1)), 1, DAIUNI.address, connectorsAddressUNI, connectorsAmountUNI, [], "0x")


      // get BNT pool addresses and connectors
      const {
        connectorsAddress:connectorsAddressBNT,
        connectorsAmount:сonnectorsAmountBNT
      } = await poolPortal.getDataForBuyingPool(
        DAIBNT.address,
        0,
        toWei(String(2)))

      // Buy BNT Pool
      await smartFundETH.buyPool(toWei(String(2)), 0, DAIBNT.address, connectorsAddressBNT, сonnectorsAmountBNT, [], "0x")

      await smartFundETH.withdraw(0)

      // investor get his BNT and UNI pools
      assert.equal(await DAIBNT.balanceOf(userOne), toWei(String(2)))
      assert.equal(await DAIUNI.balanceOf(userOne), toWei(String(2)))
    })
  })

  describe('Platform cut', function() {
    it('Platform can get 10% from ETH profit', async function() {
      // deploy smartFund with 10% success fee and platform fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
      await exchangePortal.pay({ from: userOne, value: toWei(String(3))})

      // deposit in fund
      await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)

      // 1 token is now worth 2 ether
      await exchangePortal.setRatio(1, 2)

      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(2)))

      // get proof and position for dest token
      const proofETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => buf2hex(x.data))
      const positionETH = MerkleTREE.getProof(keccak256(ETH_TOKEN_ADDRESS)).map(x => x.position === 'right' ? 1 : 0)

      // should receive 200 'ether' (wei)
      await smartFundETH.trade(
        xxxERC.address,
        toWei(String(1)),
        ETH_TOKEN_ADDRESS,
        0,
        proofETH,
        positionETH,
        PARASWAP_MOCK_ADDITIONAL_PARAMS,
        1,
        {
          from: userOne,
        }
      )

      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(2)))

      const totalWeiDeposited = await smartFundETH.totalWeiDeposited()
      assert.equal(fromWei(totalWeiDeposited), 1)

      // user1 now withdraws 190 ether, 90 of which are profit
      await smartFundETH.withdraw(0, { from: userOne })

      const totalWeiWithdrawn = await smartFundETH.totalWeiWithdrawn()
      assert.equal(fromWei(totalWeiWithdrawn), 1.9)

      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(0.1)))

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } =
      await smartFundETH.calculateFundManagerCut()

      assert.equal(fundValue, toWei(String(0.1)))
      assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
      assert.equal(fundManagerTotalCut, toWei(String(0.1)))

      // // FM now withdraws their profit
      await smartFundETH.fundManagerWithdraw({ from: userOne })

      // Platform get 10%
      assert.equal(fromWei(await web3.eth.getBalance(COT_DAO_WALLET.address)), 0.01)

      // Fund transfer all balance
      assert.equal(fromWei(await web3.eth.getBalance(smartFundETH.address)), 0)
    })

    it('Platform can get 10% from ERC profit', async function() {
      // deploy smartFund with 10% success fee and platform fee
      await deployContracts(1000)
      // give exchange portal contract some money
      await xxxERC.transfer(exchangePortal.address, toWei(String(50)))
      await exchangePortal.pay({ from: userOne, value: toWei(String(3))})

      // deposit in fund
      await smartFundETH.deposit({ from: userOne, value: toWei(String(1)) })

      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

      // 1 token is now cost 1 ether
      await exchangePortal.setRatio(1, 1)

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      await smartFundETH.trade(
        ETH_TOKEN_ADDRESS,
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

      assert.equal(await web3.eth.getBalance(smartFundETH.address), 0)

      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(1)))

      // 1 token is now worth 2 ether
      await exchangePortal.setRatio(1, 2)

      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(2)))

      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(0)))
      assert.equal(await xxxERC.balanceOf(smartFundETH.address), toWei(String(1)))

      const totalWeiDeposited = await smartFundETH.totalWeiDeposited()
      assert.equal(fromWei(totalWeiDeposited), 1)

      // user1 now withdraws 190 ether, 90 of which are profit
      await smartFundETH.withdraw(0, { from: userOne })

      const totalWeiWithdrawn = await smartFundETH.totalWeiWithdrawn()
      assert.equal(fromWei(totalWeiWithdrawn), 1.9)

      assert.equal(await smartFundETH.calculateFundValue(), toWei(String(0.1)))

      const {
        fundManagerRemainingCut,
        fundValue,
        fundManagerTotalCut,
      } =
      await smartFundETH.calculateFundManagerCut()

      assert.equal(fundValue, toWei(String(0.1)))
      assert.equal(fundManagerRemainingCut, toWei(String(0.1)))
      assert.equal(fundManagerTotalCut, toWei(String(0.1)))

      // // FM now withdraws their profit
      await smartFundETH.fundManagerWithdraw({ from: userOne })

      // Platform get 10%
      // 0.005 xxx = 0.01 ETH
      assert.equal(fromWei(await xxxERC.balanceOf(COT_DAO_WALLET.address)), 0.005)

      // Fund transfer all balance
      assert.equal(fromWei(await xxxERC.balanceOf(smartFundETH.address)), 0)
    })
  })

  describe('ERC20 implementation', function() {
    it('should be able to transfer shares to another user', async function() {
      await smartFundETH.deposit({ from: userTwo, value: 100 })
      assert.equal(await smartFundETH.balanceOf(userTwo), toWei(String(1)))

      await smartFundETH.transfer(userThree, toWei(String(1)), { from: userTwo })
      assert.equal(await smartFundETH.balanceOf(userThree), toWei(String(1)))
      assert.equal(await smartFundETH.balanceOf(userTwo), 0)
    })

    it('should allow a user to withdraw their shares that were transfered to them', async function() {
      await smartFundETH.deposit({ from: userTwo, value: 100 })
      await smartFundETH.transfer(userThree, toWei(String(1)), { from: userTwo })
      assert.equal(await smartFundETH.balanceOf(userThree), toWei(String(1)))
      await smartFundETH.withdraw(0, { from: userThree })
      assert.equal(await smartFundETH.balanceOf(userThree), 0)
    })
  })

  describe('Whitelist Investors', function() {
    it('should not allow anyone to deposit when whitelist is empty and set', async function() {
      await smartFundETH.setWhitelistOnly(true)
      await smartFundETH.deposit({ from: userTwo, value: 100 }).should.be.rejectedWith(EVMRevert)
      await smartFundETH.deposit({ from: userThree, value: 100 }).should.be.rejectedWith(EVMRevert)
    })

    it('should only allow whitelisted addresses to deposit', async function() {
      await smartFundETH.setWhitelistOnly(true)
      await smartFundETH.setWhitelistAddress(userOne, true)
      await smartFundETH.deposit({ from: userOne, value: 100 })
      await smartFundETH.deposit({ from: userTwo, value: 100 }).should.be.rejectedWith(EVMRevert)
      await smartFundETH.setWhitelistAddress(userTwo, true)
      await smartFundETH.deposit({ from: userTwo, value: 100 })
      assert.equal(await smartFundETH.addressToShares.call(userOne), toWei(String(1)))
      assert.equal(await smartFundETH.addressToShares.call(userTwo), toWei(String(1)))
      await smartFundETH.setWhitelistAddress(userOne, false)
      await smartFundETH.deposit({ from: userOne, value: 100 }).should.be.rejectedWith(EVMRevert)
      await smartFundETH.setWhitelistOnly(false)
      await smartFundETH.deposit({ from: userOne, value: 100 })
      assert.equal(await smartFundETH.addressToShares.call(userOne), toWei(String(2)))
    })
  })

  describe('Update addresses', function() {
    const testAddress = '0x0000000000000000000000000000000000000777'

    // exchange portal
    it('Owner should not be able change NON permitted exchane portal', async function() {
      await smartFundETH.setNewExchangePortal(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Owner should be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 1)
      await smartFundETH.setNewExchangePortal(testAddress)
      assert.equal(testAddress, await smartFundETH.exchangePortal())
    })

    it('NOT Owner should NOT be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 1)
      await smartFundETH.setNewExchangePortal(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    // pool portal
    it('Owner should not be able change NON permitted exchane portal', async function() {
      await smartFundETH.setNewPoolPortal(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Owner should be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 2)
      await smartFundETH.setNewPoolPortal(testAddress)
      assert.equal(testAddress, await smartFundETH.poolPortal())
    })

    it('NOT Owner should NOT be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 2)
      await smartFundETH.setNewPoolPortal(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    // defi portal
    it('Owner should not be able change NON permitted exchane portal', async function() {
      await smartFundETH.setNewDefiPortal(testAddress).should.be.rejectedWith(EVMRevert)
    })

    it('Owner should be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 3)
      await smartFundETH.setNewDefiPortal(testAddress)
      assert.equal(testAddress, await smartFundETH.defiPortal())
    })

    it('NOT Owner should NOT be able change permitted exchane portal', async function() {
      await permittedAddresses.addNewAddress(testAddress, 3)
      await smartFundETH.setNewDefiPortal(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })
  })
  //END
})
