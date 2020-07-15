pragma solidity ^0.6.0;

/*
* This contract allow buy/sell pool for Bancor and Uniswap assets
* and provide ratio and addition info for pool assets
*/

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

import "../../bancor/interfaces/BancorConverterInterface.sol";
import "../../bancor/interfaces/IGetBancorData.sol";
import "../../bancor/interfaces/SmartTokenInterface.sol";
import "../../bancor/interfaces/IBancorFormula.sol";

import "../../uniswap/interfaces/UniswapExchangeInterface.sol";
import "../../uniswap/interfaces/UniswapFactoryInterface.sol";

import "../interfaces/ITokensTypeStorage.sol";

contract PoolPortal {
  using SafeMath for uint256;

  IGetBancorData public bancorData;
  UniswapFactoryInterface public uniswapFactory;

  // CoTrader platform recognize ETH by this address
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  // Enum
  // NOTE: You can add a new type at the end, but do not change this order
  enum PortalType { Bancor, Uniswap }

  // events
  event BuyPool(address poolToken, uint256 amount, address trader);
  event SellPool(address poolToken, uint256 amount, address trader);

  // Contract for handle tokens types
  ITokensTypeStorage public tokensTypes;

  /**
  * @dev contructor
  *
  * @param _bancorData             address of helper contract GetBancorData
  * @param _uniswapFactory         address of Uniswap factory contract
  * @param _tokensTypes            address of the ITokensTypeStorage
  */
  constructor(
    address _bancorData,
    address _uniswapFactory,
    address _tokensTypes

  )
  public
  {
    bancorData = IGetBancorData(_bancorData);
    uniswapFactory = UniswapFactoryInterface(_uniswapFactory);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
  }


  /**
  * @dev buy Bancor or Uniswap pool
  *
  * @param _amount     amount of pool token
  * @param _type       pool type
  * @param _poolToken  pool token address
  */
  function buyPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken
  )
  external
  payable
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  )
  {
    if(_type == uint(PortalType.Bancor)){
      (connectorsAddress, connectorsAmount,) = buyBancorPool(_poolToken, _amount);
    }
    else if (_type == uint(PortalType.Uniswap)){
      require(_amount == msg.value, "Not enough ETH");
       (connectorsAddress, connectorsAmount,) = buyUniswapPool(address(_poolToken), _amount);
    }
    else{
      // unknown portal type
      revert();
    }

    emit BuyPool(address(_poolToken), _amount, msg.sender);
  }

  /**
  * @dev this function provide necessary data for buy a pool token by a certain amount
  *
  * @param _amount     amount of pool token (or ETH for Uniswap)
  * @param _type       pool type
  * @param _poolToken  pool token address
  */
  function getDataForBuyingPool(IERC20 _poolToken, uint _type, uint256 _amount)
    public
    view
    returns(
      address[] memory connectorsAddress,
      uint256[] memory connectorsAmount
    )
  {
    if(_type == uint(PortalType.Bancor)){
      // get Bancor converter
      address converterAddress = getBacorConverterAddressByRelay(address(_poolToken));
      // get converter as contract
      BancorConverterInterface converter = BancorConverterInterface(converterAddress);
      uint256 connectorsCount = converter.connectorTokenCount();

      // create arrays for data
      connectorsAddress = new address[](connectorsCount);
      connectorsAmount = new uint256[](connectorsCount);

      // push data
      for(uint8 i = 0; i < connectorsCount; i++){
        // get current connector address
        IERC20 currentConnector = converter.connectorTokens(i);
        // push address of current connector
        connectorsAddress[i] = address(currentConnector);
        // push amount for current connector
        connectorsAmount[i] = getBancorConnectorsAmountByRelayAmount(
          _amount, _poolToken, address(currentConnector));
      }
    }
    else if(_type == uint(PortalType.Uniswap)){
      // get token address
      address tokenAddress = uniswapFactory.getToken(address(_poolToken));
      // get tokens amd approve to exchange
      uint256 erc20Amount = getUniswapTokenAmountByETH(tokenAddress, _amount);

      // return data
      connectorsAddress = new address[](2);
      connectorsAmount = new uint256[](2);
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = tokenAddress;
      connectorsAmount[0] = _amount;
      connectorsAmount[1] = erc20Amount;

    }
    else {
      revert("Unknown pool type");
    }
  }


  /**
  * @dev helper for buy pool in Bancor network
  *
  * @param _poolToken        address of bancor converter
  * @param _amount           amount of bancor relay
  */
  function buyBancorPool(IERC20 _poolToken, uint256 _amount)
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount,
     uint256 poolAmountReceive
   )
  {
    // get Bancor converter
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken));
    // get converter as contract
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);
    // get connectors and amount
    (connectorsAddress, connectorsAmount) = getDataForBuyingPool(_poolToken, 0, _amount);

    // for detect if there are ETH in connectors or not
    uint256 etherAmount = 0;

    // approve from portal to converter
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] != address(ETH_TOKEN_ADDRESS)){
        // reset approve (some ERC20 not allow do new approve if already approved)
        IERC20(connectorsAddress[i]).approve(converterAddress, 0);
        // transfer from fund and approve to converter
        _transferFromSenderAndApproveTo(IERC20(connectorsAddress[i]), connectorsAmount[i], converterAddress);
      }else{
        etherAmount = connectorsAmount[i];
      }
    }

    // buy relay from converter
    if(etherAmount > 0){
      // payable
      converter.fund.value(etherAmount)(_amount);
    }else{
      // non payable
      converter.fund(_amount);
    }

    // addition check
    require(_amount > 0, "BNT pool recieved amount can not be zerro");

    // transfer relay back to smart fund
    _poolToken.transfer(msg.sender, _amount);
    poolAmountReceive = _amount;

    // transfer connectors back to fund if some amount remains
    uint256 remains = 0;
    for(uint8 j = 0; j < connectorsAddress.length; j++){
      remains = IERC20(connectorsAddress[j]).balanceOf(address(this));
      if(remains > 0)
         IERC20(connectorsAddress[j]).transfer(msg.sender, remains);
    }

    setTokenType(address(_poolToken), "BANCOR_ASSET");
  }


  /**
  * @dev helper for buy pool in Uniswap network
  *
  * @param _poolToken        address of Uniswap exchange
  * @param _ethAmount        ETH amount (in wei)
  */
  function buyUniswapPool(address _poolToken, uint256 _ethAmount)
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount,
     uint256 poolAmountReceive
   )
  {
    // get token address
    address tokenAddress = uniswapFactory.getToken(_poolToken);
    // check if such a pool exist
    if(tokenAddress != address(0x0000000000000000000000000000000000000000)){
      // get tokens amd approve to exchange
      uint256 erc20Amount = getUniswapTokenAmountByETH(tokenAddress, _ethAmount);
      _transferFromSenderAndApproveTo(IERC20(tokenAddress), erc20Amount, _poolToken);
      // get exchange contract
      UniswapExchangeInterface exchange = UniswapExchangeInterface(_poolToken);
      // set deadline
      uint256 deadline = now + 15 minutes;
      // buy pool
      uint256 poolAmount = exchange.addLiquidity.value(_ethAmount)(
        1,
        erc20Amount,
        deadline);

      // reset approve (some ERC20 not allow do new approve if already approved)
      IERC20(tokenAddress).approve(_poolToken, 0);

      // addition check
      require(poolAmount > 0, "UNI pool received amount can not be zerro");

      // return data
      connectorsAddress = new address[](2);
      connectorsAmount = new uint256[](2);
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = tokenAddress;
      connectorsAmount[0] = _ethAmount;
      connectorsAmount[1] = erc20Amount;
      poolAmountReceive = poolAmount;

      // transfer pool token back to smart fund
      IERC20(_poolToken).transfer(msg.sender, poolAmount);

      // transfer remains ERC20
      uint256 remainsERC = IERC20(tokenAddress).balanceOf(address(this));
      if(remainsERC > 0)
          IERC20(tokenAddress).transfer(msg.sender, remainsERC);

      setTokenType(_poolToken, "UNISWAP_POOL");
    }else{
      // throw if such pool not Exist in Uniswap network
      revert("Unknown UNI pool address");
    }
  }

  /**
  * @dev return token amount by ETH input ratio
  *
  * @param _token     address of ERC20 token
  * @param _amount    ETH amount (in wei)
  */
  function getUniswapTokenAmountByETH(address _token, uint256 _amount)
    public
    view
    returns(uint256)
  {
    UniswapExchangeInterface exchange = UniswapExchangeInterface(
      uniswapFactory.getExchange(_token));
    return exchange.getTokenToEthOutputPrice(_amount);
  }


  /**
  * @dev sell Bancor or Uniswap pool
  *
  * @param _amount     amount of pool token
  * @param _type       pool type
  * @param _poolToken  pool token address
  */
  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken
  )
  external
  payable
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount,
    uint256 poolAmountSent
  )
  {
    if(_type == uint(PortalType.Bancor)){
      (connectorsAddress,
       connectorsAmount,
       poolAmountSent) = sellPoolViaBancor(_poolToken, _amount);
    }
    else if (_type == uint(PortalType.Uniswap)){
      (connectorsAddress,
       connectorsAmount,
       poolAmountSent) = sellPoolViaUniswap(_poolToken, _amount);
    }
    else{
      // unknown portal type
      revert();
    }

    emit SellPool(address(_poolToken), _amount, msg.sender);
  }

  /**
  * @dev helper for sell pool in Bancor network
  *
  * @param _poolToken        address of bancor relay
  * @param _amount           amount of bancor relay
  */
  function sellPoolViaBancor(IERC20 _poolToken, uint256 _amount)
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount,
     uint256 poolAmountSent
   )
  {
    // transfer pool from fund
    _poolToken.transferFrom(msg.sender, address(this), _amount);
    // get Bancor Converter address
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken));

    // liquidate relay
    BancorConverterInterface(converterAddress).liquidate(_amount);
    poolAmountSent = _amount;

    // get connectors
    (connectorsAddress) = getBancorConnectorsByRelay(address(_poolToken));
    // define connectors amount length
    connectorsAmount = new uint256[](connectorsAddress.length);

    // transfer connectors back to fund
    uint256 received = 0;
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] == address(ETH_TOKEN_ADDRESS)){
        // tarnsfer ETH
        received = address(this).balance;
        (msg.sender).transfer(received);
        connectorsAmount[i] = received;
      }else{
        // transfer ERC20
        received = IERC20(connectorsAddress[i]).balanceOf(address(this));
        IERC20(connectorsAddress[i]).transfer(msg.sender, received);
        connectorsAmount[i] = received;
      }
    }
  }


  /**
  * @dev helper for sell pool in Uniswap network
  *
  * @param _poolToken        address of uniswap exchane
  * @param _amount           amount of uniswap pool
  */
  function sellPoolViaUniswap(IERC20 _poolToken, uint256 _amount)
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount,
     uint256 poolAmountSent
  )
  {
    address tokenAddress = uniswapFactory.getToken(address(_poolToken));
    // check if such a pool exist
    if(tokenAddress != address(0x0000000000000000000000000000000000000000)){
      UniswapExchangeInterface exchange = UniswapExchangeInterface(address(_poolToken));
      // approve pool token
      _transferFromSenderAndApproveTo(IERC20(_poolToken), _amount, address(_poolToken));
      // get min returns
      (uint256 minEthAmount,
        uint256 minErcAmount) = getUniswapConnectorsAmountByPoolAmount(
          _amount,
          address(_poolToken));
      // set deadline
      uint256 deadline = now + 15 minutes;

      // liquidate
      (uint256 eth_amount,
       uint256 token_amount) = exchange.removeLiquidity(
         _amount,
         minEthAmount,
         minErcAmount,
         deadline);

      // return data
      connectorsAddress = new address[](2);
      connectorsAmount = new uint256[](2);
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = tokenAddress;
      connectorsAmount[0] = eth_amount;
      connectorsAmount[1] = token_amount;
      poolAmountSent = _amount;

      // transfer assets back to smart fund
      msg.sender.transfer(eth_amount);
      IERC20(tokenAddress).transfer(msg.sender, token_amount);
    }else{
      revert();
    }
  }

  /**
  * @dev helper for get bancor converter by bancor relay addrses
  *
  * @param _relay       address of bancor relay
  */
  function getBacorConverterAddressByRelay(address _relay)
    public
    view
    returns(address converter)
  {
    converter = SmartTokenInterface(_relay).owner();
  }


  /**
  * @dev helper for get Bancor ERC20 connectors addresses
  *
  * @param _relay       address of bancor relay
  */
  function getBancorConnectorsByRelay(address _relay)
    public
    view
    returns(address[] memory connectorsAddress)
  {
    address converterAddress = getBacorConverterAddressByRelay(_relay);
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);
    uint256 connectorsCount = converter.connectorTokenCount();
    connectorsAddress = new address[](connectorsCount);

    for(uint8 i = 0; i<connectorsCount; i++){
      connectorsAddress[i] = address(converter.connectorTokens(i));
    }
  }


  /**
  * @dev return ERC20 address from Uniswap exchange address
  *
  * @param _exchange       address of uniswap exchane
  */
  function getTokenByUniswapExchange(address _exchange)
    external
    view
    returns(address)
  {
    return uniswapFactory.getToken(_exchange);
  }


  /**
  * @dev helper for get amounts for both Uniswap connectors for input amount of pool
  *
  * @param _amount         relay amount
  * @param _exchange       address of uniswap exchane
  */
  function getUniswapConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
    public
    view
    returns(uint256 ethAmount, uint256 ercAmount)
  {
    IERC20 token = IERC20(uniswapFactory.getToken(_exchange));
    // total_liquidity exchange.totalSupply
    uint256 totalLiquidity = UniswapExchangeInterface(_exchange).totalSupply();
    // ethAmount = amount * exchane.eth.balance / total_liquidity
    ethAmount = _amount.mul(_exchange.balance).div(totalLiquidity);
    // ercAmount = amount * token.balanceOf(exchane) / total_liquidity
    ercAmount = _amount.mul(token.balanceOf(_exchange)).div(totalLiquidity);
  }


  /**
  * @dev helper for get value in pool for a certain connector address
  *
  * @param _amount      relay amount
  * @param _relay       address of bancor relay
  * @param _connector   address of relay connector
  */
  function getBancorConnectorsAmountByRelayAmount
  (
    uint256 _amount,
    IERC20  _relay,
    address _connector
  )
    public
    view
    returns(uint256 connectorAmount)
  {
    // get converter contract
    BancorConverterInterface converter = BancorConverterInterface(
      SmartTokenInterface(address(_relay)).owner());

    // get connector balance
    uint256 connectorBalance = converter.getConnectorBalance(IERC20(_connector));

    // get bancor formula contract
    IBancorFormula bancorFormula = IBancorFormula(
      bancorData.getBancorContractAddresByName("BancorFormula"));

    // calculate input
    connectorAmount = bancorFormula.calculateFundCost(
      _relay.totalSupply(),
      connectorBalance,
      1000000,
       _amount);
  }


  /**
  * @dev helper for get ratio between assets in bancor newtork
  *
  * @param _from      token or relay address
  * @param _to        token or relay address
  * @param _amount    amount from
  */
  function getBancorRatio(address _from, address _to, uint256 _amount)
  external
  view
  returns(uint256)
  {
    // return Bancor ratio
    return bancorData.getBancorRatioForAssets(IERC20(_from), IERC20(_to), _amount);
  }


  /**
  * @dev Transfers tokens to this contract and approves them to another address
  *
  * @param _source          Token to transfer and approve
  * @param _sourceAmount    The amount to transfer and approve (in _source token)
  * @param _to              Address to approve to
  */
  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));

    _source.approve(_to, _sourceAmount);
  }

  // Pool portal can mark each pool token as UNISWAP or BANCOR
  function setTokenType(address _token, string memory _type) private {
    // no need add type, if token alredy registred
    if(tokensTypes.isRegistred(_token))
      return;

    tokensTypes.addNewTokenType(_token,  _type);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}
}
