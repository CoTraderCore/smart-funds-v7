pragma solidity ^0.6.0;

/*
* This contract allow buy/sell pool for Bancor and Uniswap assets
* and provide ratio and addition info for pool assets
*/

import "../../zeppelin-solidity/contracts/access/Ownable.sol";
import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

import "../../bancor/interfaces/BancorConverterInterface.sol";
import "../../bancor/interfaces/BancorConverterInterfaceV1.sol";
import "../../bancor/interfaces/IGetBancorData.sol";
import "../../bancor/interfaces/SmartTokenInterface.sol";
import "../../bancor/interfaces/IBancorFormula.sol";

import "../../uniswap/interfaces/UniswapExchangeInterface.sol";
import "../../uniswap/interfaces/UniswapFactoryInterface.sol";

import "../interfaces/ITokensTypeStorage.sol";

contract PoolPortal is Ownable{
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
  * @dev this function provide necessary data for buy a BNT v0 and UNI v1 pool token by input
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
    // Buy Bancor pool
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
    // Buy Uniswap pool
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
  * @dev buy Bancor or Uniswap pool
  *
  * @param _amount             amount of pool token
  * @param _type               pool type
  * @param _poolToken          pool token address
  * @param _connectorsAddress  address of pool connectors
  * @param _connectorsAmount   amount of pool connectors
  * @param _additionalArgs     bytes32 array for case if need pass some extra params, can be empty
  * @param _additionalData     for provide any additional data, if not used just set "0x",
  * for Bancor _additionalData[0] should be converterVersion and _additionalData[1] should be converterType
  *
  */
  function buyPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  payable
  returns(uint256 poolAmountReceive)
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
      require(_amount == msg.value, "Not enough ETH");
       (poolAmountReceive) = buyUniswapPool(
         address(_poolToken),
         _connectorsAddress[1], // connector token address
         _connectorsAmount[1],  // conenctor token amount
         _amount);
    }
    else{
      // unknown portal type
      revert();
    }

    emit BuyPool(address(_poolToken), poolAmountReceive, msg.sender);
  }

  // helper for buying Bancor pool
  // Bancor has 3 pool cases
  function buyBancorPool(
    uint256 _amount,
    IERC20 _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
    private
    returns(uint256 poolAmountReceive)
  {
    // buy pool according version and type
    // encode and compare converter version
    if(uint256(_additionalArgs[0]) >= 28){
      // buy Bancor v2
      // encode and compare converter type
      if(uint256(_additionalArgs[1]) == 2){
        (poolAmountReceive) = buyBancorPoolV2(
          _poolToken,
          _connectorsAddress,
          _connectorsAmount,
          _additionalData
        );
      }
      // buy Bancor v1
      else{
        (poolAmountReceive) = buyBancorPoolV1(
          _poolToken,
          _connectorsAddress,
          _connectorsAmount,
          _additionalData
        );
      }
    }
    // buy Bancor old v0
    else {
      (poolAmountReceive) = buyBancorPoolV0(
        _poolToken,
        _connectorsAddress,
        _connectorsAmount,
        _amount
      );
    }
  }



  /**
  * @dev helper for buy pool in Bancor network for converter type 0
  * v0 calculate by pool amount input
  *
  * @param _poolToken        address of bancor converter
  * @param _amount           amount of bancor relay
  */
  function buyBancorPoolV0(
    IERC20 _poolToken,
    address[] memory _connectorsAddress,
    uint256[] memory _connectorsAmount,
    uint256 _amount)
   private
   returns(uint256 poolAmountReceive)
  {
    // get Bancor converter
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken));
    // get converter as contract
    BancorConverterInterface converter = BancorConverterInterface(converterAddress);
    // transfer from sender and approve to converter
    // for detect if there are ETH in connectors or not we use etherAmount
    uint256 etherAmount = approveBancorConnectors(
      _connectorsAddress,
      _connectorsAmount,
      converterAddress);

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
    transferBancorRemains(_connectorsAddress);
    // transfer relay back to smart fund
    _poolToken.transfer(msg.sender, _amount);
    poolAmountReceive = _amount;
    // set token type for this asset
    setTokenType(address(_poolToken), "BANCOR_ASSET");
  }

  /**
  * @dev helper for buy pool in Bancor network for converter type 1
  * v1 calculoate pool by connectors amount
  *
  * @param _poolToken         address of bancor converter
  * @param _additionalData    bytes data
  */
  function buyBancorPoolV1(
    IERC20 _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes memory _additionalData)
    private
    returns(
    uint256 poolAmountReceive
  )
  {
    // get Bancor converter
    address converterAddress = getBacorConverterAddressByRelay(address(_poolToken));
    BancorConverterInterfaceV1 converter = BancorConverterInterfaceV1(converterAddress);

    // get additional data
    (uint256 minReturn) = abi.decode(_additionalData, (uint256));

    // transfer from sender and approve to converter
    // for detect if there are ETH in connectors or not we use etherAmount
    uint256 etherAmount = approveBancorConnectors(
      _connectorsAddress,
      _connectorsAmount,
      converterAddress);

    IERC20[] memory IERC20Tokens = convertFromAddressToIERC20(_connectorsAddress);

    // buy relay from converter
    if(etherAmount > 0){
      // payable
      converter.addLiquidity.value(etherAmount)(IERC20Tokens, _connectorsAmount, minReturn);
    }else{
      // non payable
      converter.addLiquidity(IERC20Tokens, _connectorsAmount, minReturn);
    }

    // transfer remains back to fund
    transferBancorRemains(_connectorsAddress);
    // get pool amount
    poolAmountReceive = _poolToken.balanceOf(address(this));
    // additional check
    require(poolAmountReceive > 0, "BNT pool recieved amount can not be zerro");
    // transfer relay back to smart fund
    _poolToken.transfer(msg.sender, poolAmountReceive);
    // set token type for this asset
    setTokenType(address(_poolToken), "BANCOR_ASSET");
  }

  /**
  * @dev helper for buy pool in Bancor network for converter type 2
  * v 2 works by connectors amount
  *
  * @param _poolToken         address of bancor converter
  * @param _additionalData    bytes data
  */
  function buyBancorPoolV2(
    IERC20 _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes memory _additionalData)
    private
    returns(uint256 poolAmountReceive)
  {
    // TODO
  }

  // helper for buying bancor pool v1 and v2 functions
  // approved connectors from sender to converter
  function approveBancorConnectors(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount,
    address converterAddress
  )
    private
    returns(uint256 etherAmount)
  {
    // approve from portal to converter
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] != address(ETH_TOKEN_ADDRESS)){
        // reset approve (some ERC20 not allow do new approve if already approved)
        IERC20(connectorsAddress[i]).approve(converterAddress, 0);
        // transfer from msg.sender and approve to
        _transferFromSenderAndApproveTo(
          IERC20(connectorsAddress[i]),
          connectorsAmount[i],
          converterAddress);
      }else{
        etherAmount = connectorsAmount[i];
      }
    }
  }

  // helper for buying bancor pool v1 and v2 functions
  // transfer remains assets after bying pool
  function transferBancorRemains(address[] memory connectorsAddress) private {
    // transfer connectors back to fund if some amount remains
    uint256 remains = 0;
    for(uint8 j = 0; j < connectorsAddress.length; j++){
      remains = IERC20(connectorsAddress[j]).balanceOf(address(this));
      if(remains > 0)
         IERC20(connectorsAddress[j]).transfer(msg.sender, remains);
    }
  }

  // helper for buying bancor pool v2 functions
  // convert address type to IERC20 type
  function convertFromAddressToIERC20(address[] memory _addresses)
   private
   pure
   returns(IERC20[] memory IERC20Tokens)
   {
     IERC20Tokens = new IERC20[](_addresses.length);
     for(uint8 i = 0; i < _addresses.length; i ++){
       IERC20Tokens[i] = IERC20(_addresses[i]);
     }
   }


  /**
  * @dev helper for buy pool in Uniswap network
  *
  * @param _poolToken        address of Uniswap exchange
  * @param _tokenAddress     address of ERC20 conenctor
  * @param _erc20Amount      amount of ERC20 connector
  * @param _ethAmount        ETH amount (in wei)
  */
  function buyUniswapPool(
    address _poolToken,
    address _tokenAddress,
    uint256 _erc20Amount,
    uint256 _ethAmount
  )
   private
   returns(uint256 poolAmountReceive)
  {
    // check if such a pool exist
    if(_tokenAddress != address(0x0000000000000000000000000000000000000000)){
      // transfer ERC20 connector from sender and approve to UNI pool token
      _transferFromSenderAndApproveTo(IERC20(_tokenAddress), _erc20Amount, _poolToken);
      // get exchange contract
      UniswapExchangeInterface exchange = UniswapExchangeInterface(_poolToken);
      // set deadline
      uint256 deadline = now + 15 minutes;
      // buy pool
      uint256 poolAmountReceive = exchange.addLiquidity.value(_ethAmount)(
        1,
        _erc20Amount,
        deadline);

      // reset approve (some ERC20 not allow do new approve if already approved)
      IERC20(_tokenAddress).approve(_poolToken, 0);

      // addition check
      require(poolAmountReceive > 0, "UNI pool received amount can not be zerro");

      // transfer pool token back to smart fund
      IERC20(_poolToken).transfer(msg.sender, poolAmountReceive);

      // transfer remains ERC20
      uint256 remainsERC = IERC20(_tokenAddress).balanceOf(address(this));
      if(remainsERC > 0)
          IERC20(_tokenAddress).transfer(msg.sender, remainsERC);

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
  * @param _additionalArgs  bytes32 array for case if need pass some extra params, can be empty
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
  payable
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount,
    uint256 poolAmountSent
  )
  {
    // Sell Bancor Pool
    if(_type == uint(PortalType.Bancor)){
      // get Bancor converter version and type
      uint256 bancorPoolVersion = uint256(_additionalArgs[0]);
      uint256 bancorConverterType = uint256(_additionalArgs[1]);

      if(bancorPoolVersion >= 28){
        // sell Bancor v2 pool
        if(bancorConverterType == 2){
          (connectorsAddress, connectorsAmount, poolAmountSent) = sellPoolViaBancorV2(
            _poolToken,
            _amount
          );
        }
        // sell new Bancor v1 pool
        else{
          (connectorsAddress,
           connectorsAmount,
            poolAmountSent) = sellPoolViaBancorV1(_poolToken, _amount, _additionalData);
        }
      }
      // sell v0 Bancor pool
      else{
        (connectorsAddress,
         connectorsAmount,
         poolAmountSent) = sellPoolViaBancorV0(_poolToken, _amount);
      }
    }
    // Sell Uniswap pool
    else if (_type == uint(PortalType.Uniswap)){
      (connectorsAddress,
       connectorsAmount,
       poolAmountSent) = sellPoolViaUniswap(_poolToken, _amount);
    }
    else{
      revert("Unknown portal type");
    }

    emit SellPool(address(_poolToken), _amount, msg.sender);
  }

  /**
  * @dev helper for sell pool in Bancor network converter v0
  *
  * @param _poolToken        address of bancor relay
  * @param _amount           amount of bancor relay
  */
  function sellPoolViaBancorV0(IERC20 _poolToken, uint256 _amount)
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
    // transfer conectors back to sender
    connectorsAmount = transferConnectorsToSender(connectorsAddress);
  }


  /**
  * @dev helper for sell pool in Bancor network converter type v1
  *
  * @param _poolToken        address of bancor relay
  * @param _amount           amount of bancor relay
  * @param _additionalData   for any additional data
  */
  function sellPoolViaBancorV1(IERC20 _poolToken, uint256 _amount, bytes memory _additionalData)
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

    uint256[] memory reserveMinReturnAmounts;
    // get connetor tokens data for remove liquidity
    (connectorsAddress, reserveMinReturnAmounts) = abi.decode(_additionalData, (address[], uint256[]));
    // convert tokens from address to IERC20 type
    IERC20[] memory IERC20Tokens = convertFromAddressToIERC20(connectorsAddress);
    // get coneverter contract
    BancorConverterInterfaceV1 converter = BancorConverterInterfaceV1(converterAddress);
    // remove liquidity
    converter.removeLiquidity(_amount, IERC20Tokens, reserveMinReturnAmounts);

    poolAmountSent = _amount;
    // transfer conectors back to sender
    connectorsAmount = transferConnectorsToSender(connectorsAddress);
  }

  /**
  * @dev helper for sell pool in Bancor network converter type v2
  *
  * @param _poolToken        address of bancor relay
  * @param _amount           amount of bancor relay
  */
  function sellPoolViaBancorV2(IERC20 _poolToken, uint256 _amount)
   private
   returns(
     address[] memory connectorsAddress,
     uint256[] memory connectorsAmount,
     uint256 poolAmountSent
   )
  {
    // transfer pool from fund
    _poolToken.transferFrom(msg.sender, address(this), _amount);
    // TODO
  }


  // helper for sell Bancor v1 and v2 pool
  // transfer reserve from sold pool share back to sender
  // return array with amount of recieved connectors
  function transferConnectorsToSender(address[] memory connectorsAddress)
    private
    returns(uint256[] memory connectorsAmount)
  {
    // define connectors amount length
    connectorsAmount = new uint256[](connectorsAddress.length);
    // transfer connectors back to fund
    uint256 received = 0;
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] == address(ETH_TOKEN_ADDRESS)){
        // tarnsfer ETH
        received = address(this).balance;
        payable(msg.sender).transfer(received);
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

  // owner of portal can change getBancorData helper, for case if Bancor do some major updates
  function senNewGetBancorData(address _bancorData) public onlyOwner {
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
