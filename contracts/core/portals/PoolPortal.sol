pragma solidity ^0.6.12;

/*
* This contract allow buy/sell pool for Bancor and Uniswap assets
* and provide ratio and addition info for pool assets
*/

import "../../zeppelin-solidity/contracts/access/Ownable.sol";
import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

import "../../bancor/interfaces/BancorConverterInterface.sol";
import "../../bancor/interfaces/BancorConverterInterfaceV1.sol";
import "../../bancor/interfaces/BancorConverterInterfaceV2.sol";
import "../../bancor/interfaces/IGetBancorData.sol";
import "../../bancor/interfaces/SmartTokenInterface.sol";
import "../../bancor/interfaces/IBancorFormula.sol";

import "../../uniswap/interfaces/UniswapExchangeInterface.sol";
import "../../uniswap/interfaces/UniswapFactoryInterfaceV1.sol";
import "../../uniswap/interfaces/IUniswapV2Router.sol";
import "../../uniswap/interfaces/IUniswapV2Pair.sol";

import "../../balancer/IBalancerPool.sol";

import "../interfaces/ITokensTypeStorage.sol";

contract PoolPortal is Ownable{
  using SafeMath for uint256;

  uint public version = 4;

  IGetBancorData public bancorData;
  UniswapFactoryInterfaceV1 public uniswapFactoryV1;
  IUniswapV2Router public uniswapV2Router;

  // CoTrader platform recognize ETH by this address
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  // Enum
  // NOTE: You can add a new type at the end, but do not change this order
  enum PortalType { Bancor, Uniswap, Balancer }

  // events
  event BuyPool(address poolToken, uint256 amount, address trader);
  event SellPool(address poolToken, uint256 amount, address trader);

  // Contract for handle tokens types
  ITokensTypeStorage public tokensTypes;


  /**
  * @dev contructor
  *
  * @param _bancorData               address of helper contract GetBancorData
  * @param _uniswapFactoryV1         address of Uniswap V1 factory contract
  * @param _uniswapV2Router          address of Uniswap V2 router
  * @param _tokensTypes              address of the ITokensTypeStorage
  */
  constructor(
    address _bancorData,
    address _uniswapFactoryV1,
    address _uniswapV2Router,
    address _tokensTypes

  )
  public
  {
    bancorData = IGetBancorData(_bancorData);
    uniswapFactoryV1 = UniswapFactoryInterfaceV1(_uniswapFactoryV1);
    uniswapV2Router = IUniswapV2Router(_uniswapV2Router);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
  }

  /**
  * @dev this function provide necessary data for buy a old BNT and UNI v1 pools by input amount
  *
  * @param _amount     amount of pool token (NOTE: amount of ETH for Uniswap)
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
    // Buy Bancor pool
    if(_type == uint(PortalType.Bancor)){
      // get Bancor converter
      address converterAddress = getBacorConverterAddressByRelay(address(_poolToken), 0);
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
    // Buy Uniswap pool
    else if(_type == uint(PortalType.Uniswap)){
      // get token address
      address tokenAddress = uniswapFactoryV1.getToken(address(_poolToken));
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
  * @dev buy Bancor or Uniswap pool
  *
  * @param _amount             amount of pool token
  * @param _type               pool type
  * @param _poolToken          pool token address (NOTE: for Bancor type 2 don't forget extract pool address from container)
  * @param _connectorsAddress  address of pool connectors (NOTE: for Uniswap ETH should be pass in [0], ERC20 in [1])
  * @param _connectorsAmount   amount of pool connectors (NOTE: for Uniswap ETH amount should be pass in [0], ERC20 in [1])
  * @param _additionalArgs     bytes32 array for case if need pass some extra params, can be empty
  * @param _additionalData     for provide any additional data, if not used just set "0x",
  * for Bancor _additionalData[0] should be converterVersion and _additionalData[1] should be converterType
  *
  */
  function buyPool
  (
    uint256 _amount,
    uint _type,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  payable
  returns(uint256 poolAmountReceive, uint256[] memory connectorsSpended)
  {
    // Buy Bancor pool
    if(_type == uint(PortalType.Bancor)){
      (poolAmountReceive) = buyBancorPool(
        _amount,
        _poolToken,
        _connectorsAddress,
        _connectorsAmount,
        _additionalArgs,
        _additionalData
      );
    }
    // Buy Uniswap pool
    else if (_type == uint(PortalType.Uniswap)){
      (poolAmountReceive) = buyUniswapPool(
        _amount,
        _poolToken,
        _connectorsAddress,
        _connectorsAmount,
        _additionalArgs,
        _additionalData
      );
    }
    // Buy Balancer pool
    else if (_type == uint(PortalType.Balancer)){
      (poolAmountReceive) = buyBalancerPool(
        _amount,
        _poolToken,
        _connectorsAddress,
        _connectorsAmount
      );
    }
    else{
      // unknown portal type
      revert("Unknown portal type");
    }

    // transfer pool token to fund
    IERC20(_poolToken).transfer(msg.sender, poolAmountReceive);

    // transfer connectors remains to fund
    // and calculate how much connectors was spended (current - remains)
    connectorsSpended = _transferPoolConnectorsRemains(
      _connectorsAddress,
      _connectorsAmount);

    // trigger event
    emit BuyPool(address(_poolToken), poolAmountReceive, msg.sender);
  }


  /**
  * @dev helper for buying Bancor pool token by a certain converter version and converter type
  * Bancor has 3 cases for different converter version and type
  */
  function buyBancorPool(
    uint256 _amount,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
    private
    returns(uint256 poolAmountReceive)
  {
    // get Bancor converter address by pool token and pool type
    address converterAddress = getBacorConverterAddressByRelay(
      _poolToken,
      uint256(_additionalArgs[1])
    );

    // transfer from sender and approve to converter
    // for detect if there are ETH in connectors or not we use etherAmount
    uint256 etherAmount = _approvePoolConnectors(
      _connectorsAddress,
      _connectorsAmount,
      converterAddress
    );

    // Buy Bancor pool according converter version and type
    // encode and compare converter version
    if(uint256(_additionalArgs[0]) >= 28) {
      // encode and compare converter type
      if(uint256(_additionalArgs[1]) == 2) {
        // buy Bancor v2 case
        _buyBancorPoolV2(
          converterAddress,
          etherAmount,
          _connectorsAddress,
          _connectorsAmount,
          _additionalData
        );
      } else{
        // buy Bancor v1 case
        _buyBancorPoolV1(
          converterAddress,
          etherAmount,
          _connectorsAddress,
          _connectorsAmount,
          _additionalData
        );
      }
    }
    else {
      // buy Bancor old v0 case
      _buyBancorPoolOldV(
        converterAddress,
        etherAmount,
        _amount
      );
    }

    // get recieved pool amount
    poolAmountReceive = IERC20(_poolToken).balanceOf(address(this));
    // make sure we recieved pool
    require(poolAmountReceive > 0, "ERR BNT pool received 0");
    // set token type for this asset
    tokensTypes.addNewTokenType(_poolToken, "BANCOR_ASSET");
  }


  /**
  * @dev helper for buy pool in Bancor network for old converter version
  */
  function _buyBancorPoolOldV(
    address converterAddress,
    uint256 etherAmount,
    uint256 _amount)
   private
  {
    // get converter as contract
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);
    // buy relay from converter
    if(etherAmount > 0){
      // payable
      converter.fund.value(etherAmount)(_amount);
    }else{
      // non payable
      converter.fund(_amount);
    }
  }


  /**
  * @dev helper for buy pool in Bancor network for new converter type 1
  */
  function _buyBancorPoolV1(
    address converterAddress,
    uint256 etherAmount,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes memory _additionalData
  )
    private
  {
    BancorConverterInterfaceV1 converter = BancorConverterInterfaceV1(converterAddress);
    // get additional data
    (uint256 minReturn) = abi.decode(_additionalData, (uint256));
    // buy relay from converter
    if(etherAmount > 0){
      // payable
      converter.addLiquidity.value(etherAmount)(_connectorsAddress, _connectorsAmount, minReturn);
    }else{
      // non payable
      converter.addLiquidity(_connectorsAddress, _connectorsAmount, minReturn);
    }
  }

  /**
  * @dev helper for buy pool in Bancor network for new converter type 2
  */
  function _buyBancorPoolV2(
    address converterAddress,
    uint256 etherAmount,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes memory _additionalData
  )
    private
  {
    // get converter as contract
    BancorConverterInterfaceV2 converter = BancorConverterInterfaceV2(converterAddress);
    // get additional data
    (uint256 minReturn) = abi.decode(_additionalData, (uint256));

    // buy relay from converter
    if(etherAmount > 0){
      // payable
      converter.addLiquidity.value(etherAmount)(_connectorsAddress[0], _connectorsAmount[0], minReturn);
    }else{
      // non payable
      converter.addLiquidity(_connectorsAddress[0], _connectorsAmount[0], minReturn);
    }
  }


  /**
  * @dev helper for buying Uniswap v1 or v2 pool
  */
  function buyUniswapPool(
    uint256 _amount,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
   private
   returns(uint256 poolAmountReceive)
  {
    // define spender dependse of UNI pool version
    address spender = uint256(_additionalArgs[0]) == 1
    ? _poolToken
    : address(uniswapV2Router);

    // approve pool tokens to Uni pool exchange
    _approvePoolConnectors(
      _connectorsAddress,
      _connectorsAmount,
      spender);

    // Buy Uni pool dependse of version
    if(uint256(_additionalArgs[0]) == 1){
      _buyUniswapPoolV1(
        _poolToken,
        _connectorsAddress[1], // connector ERC20 token address
        _connectorsAmount[1],  // connector ERC20 token amount
        _amount);
    }else{
      _buyUniswapPoolV2(
        _poolToken,
        _connectorsAddress,
        _connectorsAmount,
        _additionalData
        );
    }
    // get pool amount
    poolAmountReceive = IERC20(_poolToken).balanceOf(address(this));
    // check if we recieved pool token
    require(poolAmountReceive > 0, "ERR UNI pool received 0");
  }


  /**
  * @dev helper for buy pool in Uniswap network v1
  *
  * @param _poolToken        address of Uniswap exchange
  * @param _tokenAddress     address of ERC20 conenctor
  * @param _erc20Amount      amount of ERC20 connector
  * @param _ethAmount        ETH amount (in wei)
  */
  function _buyUniswapPoolV1(
    address _poolToken,
    address _tokenAddress,
    uint256 _erc20Amount,
    uint256 _ethAmount
  )
   private
  {
    require(_ethAmount == msg.value, "Not enough ETH");
    // get exchange contract
    UniswapExchangeInterface exchange = UniswapExchangeInterface(_poolToken);
    // set deadline
    uint256 deadline = now + 15 minutes;
    // buy pool
    exchange.addLiquidity.value(_ethAmount)(
      1,
      _erc20Amount,
      deadline
    );
    // Set token type
    tokensTypes.addNewTokenType(_poolToken, "UNISWAP_POOL");
  }


  /**
  * @dev helper for buy pool in Uniswap network v2
  */
  function _buyUniswapPoolV2(
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes calldata _additionalData
  )
   private
  {
    // set deadline
    uint256 deadline = now + 15 minutes;
    // get additional data
    (uint256 amountAMinReturn,
      uint256 amountBMinReturn) = abi.decode(_additionalData, (uint256, uint256));

    // Buy UNI V2 pool
    // ETH connector case
    if(_connectorsAddress[0] == address(ETH_TOKEN_ADDRESS)){
      uniswapV2Router.addLiquidityETH.value(_connectorsAmount[0])(
       _connectorsAddress[1],
       _connectorsAmount[1],
       amountBMinReturn,
       amountAMinReturn,
       address(this),
       deadline
      );
    }
    // ERC20 connector case
    else{
      uniswapV2Router.addLiquidity(
        _connectorsAddress[0],
        _connectorsAddress[1],
        _connectorsAmount[0],
        _connectorsAmount[1],
        amountAMinReturn,
        amountBMinReturn,
        address(this),
        deadline
      );
    }
    // Set token type
    tokensTypes.addNewTokenType(_poolToken, "UNISWAP_POOL_V2");
  }


  /**
  * @dev helper for buying Balancer pool
  */
  function buyBalancerPool(
    uint256 _amount,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount
  )
    private
    returns(uint256 poolAmountReceive)
  {
    // approve pool tokens to Balancer pool exchange
    _approvePoolConnectors(
      _connectorsAddress,
      _connectorsAmount,
      _poolToken);
    // buy pool
    IBalancerPool(_poolToken).joinPool(_amount, _connectorsAmount);
    // get balance
    poolAmountReceive = IERC20(_poolToken).balanceOf(address(this));
    // check
    require(poolAmountReceive > 0, "ERR BALANCER pool received 0");
    // update type
    tokensTypes.addNewTokenType(_poolToken, "BALANCER_POOL");
  }

  /**
  * @dev helper for buying BNT or UNI pools, approve connectors from msg.sender to spender address
  * return ETH amount if connectorsAddress contains ETH address
  */
  function _approvePoolConnectors(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount,
    address spender
  )
    private
    returns(uint256 etherAmount)
  {
    // approve from portal to spender
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] != address(ETH_TOKEN_ADDRESS)){
        // transfer from msg.sender and approve to
        _transferFromSenderAndApproveTo(
          IERC20(connectorsAddress[i]),
          connectorsAmount[i],
          spender);
      }else{
        etherAmount = connectorsAmount[i];
      }
    }
  }

  /**
  * @dev helper for buying BNT or UNI pools, transfer ERC20 tokens and ETH remains after bying pool,
  * if the balance is positive on this contract, and calculate how many assets was spent.
  */
  function _transferPoolConnectorsRemains(
    address[] memory connectorsAddress,
    uint256[] memory currentConnectorsAmount
  )
    private
    returns (uint256[] memory connectorsSpended)
  {
    // set length for connectorsSpended
    connectorsSpended = new uint256[](currentConnectorsAmount.length);

    // transfer connectors back to fund if some amount remains
    uint256 remains = 0;
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      // ERC20 case
      if(connectorsAddress[i] != address(ETH_TOKEN_ADDRESS)){
        // check balance
        remains = IERC20(connectorsAddress[i]).balanceOf(address(this));
        // transfer ERC20
        if(remains > 0)
           IERC20(connectorsAddress[i]).transfer(msg.sender, remains);
      }
      // ETH case
      else {
        remains = address(this).balance;
        // transfer ETH
        if(remains > 0)
           (msg.sender).transfer(remains);
      }

      // calculate how many assets was spent
      connectorsSpended[i] = currentConnectorsAmount[i].sub(remains);
    }
  }

  /**
  * @dev return token ration in ETH in Uniswap network
  *
  * @param _token     address of ERC20 token
  * @param _amount    ETH amount
  */
  function getUniswapTokenAmountByETH(address _token, uint256 _amount)
    public
    view
    returns(uint256)
  {
    UniswapExchangeInterface exchange = UniswapExchangeInterface(
      uniswapFactoryV1.getExchange(_token));

    return exchange.getTokenToEthOutputPrice(_amount);
  }


  /**
  * @dev sell Bancor or Uniswap pool
  *
  * @param _amount            amount of pool token
  * @param _type              pool type
  * @param _poolToken         pool token address
  * @param _additionalArgs    bytes32 array for case if need pass some extra params, can be empty
  * @param _additionalData    for provide any additional data, if not used just set "0x"
  */
  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  )
  {
    // sell Bancor Pool
    if(_type == uint(PortalType.Bancor)){
      (connectorsAddress, connectorsAmount) = sellBancorPool(
         _amount,
         _poolToken,
        _additionalArgs,
        _additionalData);
    }
    // sell Uniswap pool
    else if (_type == uint(PortalType.Uniswap)){
      (connectorsAddress, connectorsAmount) = sellUniswapPool(
        _poolToken,
        _amount,
        _additionalArgs,
        _additionalData);
    }
    // sell Balancer pool
    else if (_type == uint(PortalType.Balancer)){
      (connectorsAddress, connectorsAmount) = sellBalancerPool(
        _amount,
        _poolToken,
        _additionalData);
    }
    else{
      revert("Unknown portal type");
    }

    emit SellPool(address(_poolToken), _amount, msg.sender);
  }



  /**
  * @dev helper for sell pool in Bancor network dependse of converter version and type
  */
  function sellBancorPool(
    uint256 _amount,
    IERC20 _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  private
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  )
  {
    // transfer pool from fund
    _poolToken.transferFrom(msg.sender, address(this), _amount);

    // get Bancor converter version and type
    uint256 bancorPoolVersion = uint256(_additionalArgs[0]);
    uint256 bancorConverterType = uint256(_additionalArgs[1]);

    // sell pool according converter version and type
    if(bancorPoolVersion >= 28){
      // sell new Bancor v2 pool
      if(bancorConverterType == 2){
        (connectorsAddress) = sellPoolViaBancorV2(
          _poolToken,
          _amount,
          _additionalData
        );
      }
      // sell new Bancor v1 pool
      else{
        (connectorsAddress) = sellPoolViaBancorV1(_poolToken, _amount, _additionalData);
      }
    }
    // sell old Bancor pool
    else{
      (connectorsAddress) = sellPoolViaBancorOldV(_poolToken, _amount);
    }

    // transfer pool connectors back to fund
    connectorsAmount = transferConnectorsToSender(connectorsAddress);
  }

  /**
  * @dev helper for sell pool in Bancor network for old converter version
  *
  * @param _poolToken        address of bancor relay
  * @param _amount           amount of bancor relay
  */
  function sellPoolViaBancorOldV(IERC20 _poolToken, uint256 _amount)
   private
   returns(address[] memory connectorsAddress)
  {
    // get Bancor Converter instance
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken), 0);
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);

    // liquidate relay
    converter.liquidate(_amount);

    // return connectors addresses
    uint256 connectorsCount = converter.connectorTokenCount();
    connectorsAddress = new address[](connectorsCount);

    for(uint8 i = 0; i<connectorsCount; i++){
      connectorsAddress[i] = address(converter.connectorTokens(i));
    }
  }


  /**
  * @dev helper for sell pool in Bancor network converter type v1
  */
  function sellPoolViaBancorV1(
    IERC20 _poolToken,
    uint256 _amount,
    bytes memory _additionalData
  )
   private
   returns(address[] memory connectorsAddress)
  {
    // get Bancor Converter address
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken), 1);
    // get min returns
    uint256[] memory reserveMinReturnAmounts;
    // get connetor tokens data for remove liquidity
    (connectorsAddress, reserveMinReturnAmounts) = abi.decode(_additionalData, (address[], uint256[]));
    // get coneverter v1 contract
    BancorConverterInterfaceV1 converter = BancorConverterInterfaceV1(converterAddress);
    // remove liquidity (v1)
    converter.removeLiquidity(_amount, connectorsAddress, reserveMinReturnAmounts);
  }

  /**
  * @dev helper for sell pool in Bancor network converter type v2
  */
  function sellPoolViaBancorV2(
    IERC20 _poolToken,
    uint256 _amount,
    bytes calldata _additionalData
  )
   private
   returns(address[] memory connectorsAddress)
  {
    // get Bancor Converter address
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken), 2);
    // get converter v2 contract
    BancorConverterInterfaceV2 converter = BancorConverterInterfaceV2(converterAddress);
    // get additional data
    uint256 minReturn;
    // get pool connectors
    (connectorsAddress, minReturn) = abi.decode(_additionalData, (address[], uint256));
    // remove liquidity (v2)
    converter.removeLiquidity(address(_poolToken), _amount, minReturn);
  }

  /**
  * @dev helper for sell pool in Uniswap network for v1 and v2
  */
  function sellUniswapPool(
    IERC20 _poolToken,
    uint256 _amount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount
  )
  {
    // define spender dependse of UNI pool version
    address spender = uint256(_additionalArgs[0]) == 1
    ? address(_poolToken)
    : address(uniswapV2Router);

    // approve pool token
    _transferFromSenderAndApproveTo(_poolToken, _amount, spender);

    // sell Uni v1 or v2 pool
    if(uint256(_additionalArgs[0]) == 1){
      (connectorsAddress) = sellPoolViaUniswapV1(_poolToken, _amount);
    }else{
      (connectorsAddress) = sellPoolViaUniswapV2(_amount, _additionalData);
    }

    // transfer pool connectors back to fund
    connectorsAmount = transferConnectorsToSender(connectorsAddress);
  }


  /**
  * @dev helper for sell pool in Uniswap network v1
  */
  function sellPoolViaUniswapV1(
    IERC20 _poolToken,
    uint256 _amount
  )
    private
    returns(address[] memory connectorsAddress)
  {
    // get token by pool token
    address tokenAddress = uniswapFactoryV1.getToken(address(_poolToken));
    // check if such a pool exist
    if(tokenAddress != address(0x0000000000000000000000000000000000000000)){
      // get UNI exchane
      UniswapExchangeInterface exchange = UniswapExchangeInterface(address(_poolToken));

      // get min returns
      (uint256 minEthAmount,
       uint256 minErcAmount) = getUniswapConnectorsAmountByPoolAmount(_amount, address(_poolToken));

      // set deadline
      uint256 deadline = now + 15 minutes;

      // liquidate
      exchange.removeLiquidity(
         _amount,
         minEthAmount,
         minErcAmount,
         deadline);

      // return data
      connectorsAddress = new address[](2);
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = tokenAddress;
    }
    else{
      revert("Not exist UNI v1 pool");
    }
  }

  /**
  * @dev helper for sell pool in Uniswap network v2
  */
  function sellPoolViaUniswapV2(
    uint256 _amount,
    bytes calldata _additionalData
  )
    private
    returns(address[] memory connectorsAddress)
  {
    // get additional data
    uint256 minReturnA;
    uint256 minReturnB;

    // get connectors and min return from bytes
    (connectorsAddress,
      minReturnA,
      minReturnB) = abi.decode(_additionalData, (address[], uint256, uint256));

    // get deadline
    uint256 deadline = now + 15 minutes;

    // sell pool with include eth connector
    if(connectorsAddress[0] == address(ETH_TOKEN_ADDRESS)){
      uniswapV2Router.removeLiquidityETH(
          connectorsAddress[1],
          _amount,
          minReturnB,
          minReturnA,
          address(this),
          deadline
      );
    }
    // sell pool only with erc20 connectors
    else{
      uniswapV2Router.removeLiquidity(
          connectorsAddress[0],
          connectorsAddress[1],
          _amount,
          minReturnA,
          minReturnB,
          address(this),
          deadline
      );
    }
  }

  /**
  * @dev helper for sell Balancer pool
  */

  function sellBalancerPool(
    uint256 _amount,
    IERC20 _poolToken,
    bytes calldata _additionalData
  )
  private
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  )
  {
    // get additional data
    uint256[] memory minConnectorsAmount;
    (connectorsAddress,
      minConnectorsAmount) = abi.decode(_additionalData, (address[], uint256[]));
    // approve pool
    _transferFromSenderAndApproveTo(
      _poolToken,
      _amount,
      address(_poolToken));
    // sell pool
    IBalancerPool(address(_poolToken)).exitPool(_amount, minConnectorsAmount);
    // transfer connectors back to fund
    connectorsAmount = transferConnectorsToSender(connectorsAddress);
  }

  /**
  * @dev helper for sell Bancor and Uniswap pools
  * transfer pool connectors from sold pool back to sender
  * return array with amount of recieved connectors
  */
  function transferConnectorsToSender(address[] memory connectorsAddress)
    private
    returns(uint256[] memory connectorsAmount)
  {
    // define connectors amount length
    connectorsAmount = new uint256[](connectorsAddress.length);

    uint256 received = 0;
    // transfer connectors back to fund
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      // ETH case
      if(connectorsAddress[i] == address(ETH_TOKEN_ADDRESS)){
        // update ETH data
        received = address(this).balance;
        connectorsAmount[i] = received;
        // tarnsfer ETH
        if(received > 0)
          payable(msg.sender).transfer(received);
      }
      // ERC20 case
      else{
        // update ERC20 data
        received = IERC20(connectorsAddress[i]).balanceOf(address(this));
        connectorsAmount[i] = received;
        // transfer ERC20
        if(received > 0)
          IERC20(connectorsAddress[i]).transfer(msg.sender, received);
      }
    }
  }

  /**
  * @dev helper for get bancor converter by bancor relay addrses
  *
  * @param _relay       address of bancor relay
  * @param _poolType    bancor pool type
  */
  function getBacorConverterAddressByRelay(address _relay, uint256 _poolType)
    public
    view
    returns(address converter)
  {
    if(_poolType == 2){
      address smartTokenContainer = SmartTokenInterface(_relay).owner();
      converter = SmartTokenInterface(smartTokenContainer).owner();
    }else{
      converter = SmartTokenInterface(_relay).owner();
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
    return uniswapFactoryV1.getToken(_exchange);
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
    IERC20 token = IERC20(uniswapFactoryV1.getToken(_exchange));
    // total_liquidity exchange.totalSupply
    uint256 totalLiquidity = UniswapExchangeInterface(_exchange).totalSupply();
    // ethAmount = amount * exchane.eth.balance / total_liquidity
    ethAmount = _amount.mul(_exchange.balance).div(totalLiquidity);
    // ercAmount = amount * token.balanceOf(exchane) / total_liquidity
    ercAmount = _amount.mul(token.balanceOf(_exchange)).div(totalLiquidity);
  }

  /**
  * @dev helper for get amounts for both Uniswap connectors for input amount of pool
  * for Uniswap version 2
  *
  * @param _amount         pool amount
  * @param _exchange       address of uniswap exchane
  */
  function getUniswapV2ConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
    public
    view
    returns(
      uint256 tokenAmountOne,
      uint256 tokenAmountTwo,
      address tokenAddressOne,
      address tokenAddressTwo
    )
  {
    tokenAddressOne = IUniswapV2Pair(_exchange).token0();
    tokenAddressTwo = IUniswapV2Pair(_exchange).token1();
    // total_liquidity exchange.totalSupply
    uint256 totalLiquidity = IERC20(_exchange).totalSupply();
    // ethAmount = amount * exchane.eth.balance / total_liquidity
    tokenAmountOne = _amount.mul(IERC20(tokenAddressOne).balanceOf(_exchange)).div(totalLiquidity);
    // ercAmount = amount * token.balanceOf(exchane) / total_liquidity
    tokenAmountTwo = _amount.mul(IERC20(tokenAddressTwo).balanceOf(_exchange)).div(totalLiquidity);
  }


  /**
  * @dev helper for get amounts all Balancer connectors for input amount of pool
  * for Balancer
  *
  * step 1 get all tokens
  * step 2 get user amount from each token by a user pool share
  *
  * @param _amount         pool amount
  * @param _pool           address of balancer pool
  */
  function getBalancerConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _pool
  )
    public
    view
    returns(
      address[] memory tokens,
      uint256[] memory tokensAmount
    )
  {
    IBalancerPool balancerPool = IBalancerPool(_pool);
    // get all pool tokens
    tokens = balancerPool.getCurrentTokens();
    // set tokens amount length
    tokensAmount = new uint256[](tokens.length);
    // get total pool shares
    uint256 totalShares = IERC20(_pool).totalSupply();
    // calculate all tokens from the pool
    for(uint i = 0; i < tokens.length; i++){
      // get a certain total token amount in pool
      uint256 totalTokenAmount = IERC20(tokens[i]).balanceOf(_pool);
      // get a certain pool share (_amount) from a certain token amount in pool
      tokensAmount[i] = totalTokenAmount.mul(_amount).div(totalShares);
    }
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
  * @dev helper for get Bancor ERC20 connectors addresses for old Bancor version
  *
  * @param _relay       address of bancor relay
  */
  function getBancorConnectorsByRelay(address _relay)
    public
    view
    returns(
    IERC20[] memory connectors
    )
  {
    address converterAddress = getBacorConverterAddressByRelay(_relay, 0);
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);
    uint256 connectorTokenCount = converter.connectorTokenCount();
    connectors = new IERC20[](connectorTokenCount);

    for(uint8 i; i < connectorTokenCount; i++){
      connectors[i] = converter.connectorTokens(i);
    }
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

  // owner of portal can change getBancorData helper, for case if Bancor do some major updates
  function setNewGetBancorData(address _bancorData) public onlyOwner {
    bancorData = IGetBancorData(_bancorData);
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
    // reset previous approve (some ERC20 not allow do new approve if already approved)
    _source.approve(_to, 0);
    // approve
    _source.approve(_to, _sourceAmount);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}
}
