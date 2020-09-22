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


// real contracts
const SmartFundETH = artifacts.require('./core/full_funds/SmartFundETH.sol')
const TokensTypeStorage = artifacts.require('./core/storage/TokensTypeStorage.sol')
const MerkleWhiteList = artifacts.require('./core/verification/MerkleTreeTokensVerification.sol')

// mock contracts
const ReEntrancyFundAtack = artifacts.require('./ReEntrancyFundAtack')
const ReEntrancyFundAtackAsManager = artifacts.require('./ReEntrancyFundAtackAsManager')
const Token = artifacts.require('./tokens/Token')
const ExchangePortalMock = artifacts.require('./portalsMock/ExchangePortalMock')
const PoolPortalMock = artifacts.require('./portalsMock/PoolPortalMock')
const CoTraderDAOWalletMock = artifacts.require('./portalsMock/CoTraderDAOWalletMock')


let xxxERC,
    DAI,
    exchangePortal,
    smartFundETH,
    BNT,
    COT_DAO_WALLET,
    yyyERC,
    atackContract,
    atackContractAsManager,
    tokensType,
    merkleWhiteList,
    MerkleTREE

contract('ReEntrancy Atack', function([userOne, userTwo, userThree]) {

  async function deployContracts(successFee=1000, platformFee=0){
    COT_DAO_WALLET = await CoTraderDAOWalletMock.new()

    // Deploy xxx Token
    xxxERC = await Token.new(
      "xxxERC20",
      "xxx",
      18,
      toWei(String(100000000))
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
      toWei(String(100000000))
    )

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

    // Deploy ETH fund
    smartFundETH = await SmartFundETH.new(
      userOne,                                      // address _owner,
      'TEST ETH FUND',                              // string _name,
      successFee,                                   // uint256 _successFee,
      COT_DAO_WALLET.address,                       // address _platformAddress,
      exchangePortal.address,                       // address _exchangePortalAddress,
      '0x0000000000000000000000000000000000000000', // defi portal
      '0x0000000000000000000000000000000000000000', // poolPortalAddress,
      '0x0000000000000000000000000000000000000000', // permitted addresses
      true                                          // verification for trade tokens
    )

    // Deploy atack contracts
    atackContract = await ReEntrancyFundAtack.new(smartFundETH.address)
    atackContractAsManager = await ReEntrancyFundAtackAsManager.new(smartFundETH.address)
  }

  beforeEach(async function() {
    await deployContracts()
  })

  describe('ReEntrancy atack', function() {
    it('Users should not be able to do ReEntrancy atack', async function() {
      // atackContract deployed correct
      assert.equal(await atackContract.fundAddress(), smartFundETH.address)

      // Deposit as user
      await smartFundETH.deposit({ from: userOne, value: toWei(String(10)) })
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(10)))

      // Deposit as hacker
      await atackContract.pay({ from: userTwo, value: toWei(String(1)) })
      await atackContract.deposit(toWei(String(1)))
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(11)))

      // Atack should be rejected
      await atackContract.startAtack({ from: userTwo }).should.be.rejectedWith(EVMRevert)
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(11)))
    })


    it('Managers should not be able to do ReEntrancy atack', async function() {
      // give exchane portal some money
      await exchangePortal.pay({ from: userOne, value: toWei(String(2))})
      await xxxERC.transfer(exchangePortal.address, toWei(String(2)))

      // atackContract deployed correct
      assert.equal(await atackContractAsManager.fundAddress(), smartFundETH.address)

      // check manager address
      assert.equal(await smartFundETH.owner(), userOne)

      // Deposit as investor from user 2
      await smartFundETH.deposit({ from: userTwo, value: toWei(String(1)) })
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

      // check fund balance
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(1)))

      assert.equal(await tokensType.isPermittedAddress(exchangePortal.address), true)

      // get proof and position for dest token
      const proofXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => buf2hex(x.data))
      const positionXXX = MerkleTREE.getProof(keccak256(xxxERC.address)).map(x => x.position === 'right' ? 1 : 0)

      // Manager make profit
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

      // check fund balance (now fund balance have 2 ETH)
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(2)))

      // Atack contract now manager
      await smartFundETH.transferOwnership(atackContract.address)
      assert.equal(await smartFundETH.owner(), atackContract.address)

      // Atack
      await atackContract.startAtack({ from: userOne })

      // balance not changed
      assert.equal(await web3.eth.getBalance(smartFundETH.address), toWei(String(2)))
    })
  })

})
