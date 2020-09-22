// This contract sell/buy UNI and BNT Pool relays for DAI mock token
pragma solidity ^0.6.12;

import "../../../contracts/core/interfaces/ITokensTypeStorage.sol";
import "../../../contracts/zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../../contracts/zeppelin-solidity/contracts/token/ERC20/IERC20.sol";


contract PoolPortalMock {

  using SafeMath for uint256;

  ITokensTypeStorage public tokensTypes;

  address public DAI;
  address public BNT;
  address public DAIBNTPoolToken;
  address public DAIUNIPoolToken;
  address public ETHBNT;

  enum PortalType { Bancor, Uniswap }

  // KyberExchange recognizes ETH by this address, airswap recognizes ETH as address(0x0)
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  address constant private NULL_ADDRESS = address(0);

  constructor(
    address _BNT,
    address _DAI,
    address _DAIBNTPoolToken,
    address _DAIUNIPoolToken,
    address _ETHBNT,
    address _tokensTypes
  )
    public
  {
    DAI = _DAI;
    BNT = _BNT;
    DAIBNTPoolToken = _DAIBNTPoolToken;
    DAIUNIPoolToken = _DAIUNIPoolToken;
    ETHBNT = _ETHBNT;
    tokensTypes = ITokensTypeStorage(_tokensTypes);
  }


  // for mock 1 Relay BNT = 0.5 BNT and 0.5 ERC
  // Note: calculate by pool amount
  function buyBancorPool(IERC20 _poolToken, uint256 _amount) private {
     uint256 relayAmount = _amount.div(2);

     require(IERC20(BNT).transferFrom(msg.sender, address(this), relayAmount), "Can not transfer from");
     require(IERC20(DAI).transferFrom(msg.sender, address(this), relayAmount), "Can not transfer from");

     IERC20(DAIBNTPoolToken).transfer(msg.sender, _amount);

     setTokenType(address(_poolToken), "BANCOR_ASSET");
  }

  // for mock 1 Relay BNT = 0.5 BNT and 0.5 ETH
  // Note: calculate by pool amount
  function buyBancorPoolETH(IERC20 _poolToken, uint256 _amount) private {
     uint256 relayAmount = _amount.div(2);
     require(msg.value == relayAmount, "CANT NOT TRANSFER ETH");
     require(IERC20(BNT).transferFrom(msg.sender, address(this), relayAmount), "Can not transfer from");

     IERC20(ETHBNT).transfer(msg.sender, _amount);

     setTokenType(address(_poolToken), "BANCOR_ASSET");
  }

  // for mock 1 UNI = 0.5 ETH and 0.5 ERC
  // Note: calculate by ETH amount
  function buyUniswapPool(address _poolToken, uint256 _ethAmount) private{
    require(IERC20(DAI).transferFrom(msg.sender, address(this), _ethAmount), "Can not transfer from");
    IERC20(DAIUNIPoolToken).transfer(msg.sender, _ethAmount.mul(2));

    setTokenType(_poolToken, "UNISWAP_POOL");
  }


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
  returns(uint256 poolReceivedAmount, uint256[] memory connectorsSpended)
  {

    if(_type == uint(PortalType.Bancor)){
      if(_connectorsAddress[0] == address(ETH_TOKEN_ADDRESS)){
        buyBancorPoolETH(_poolToken, _amount);
        poolReceivedAmount = _amount;
        connectorsSpended = _connectorsAmount;
      }else{
        buyBancorPool(_poolToken, _amount);
        poolReceivedAmount = _amount;
        connectorsSpended = _connectorsAmount;
      }
    }
    else if (_type == uint(PortalType.Uniswap)){
      require(_amount == msg.value, "Not enough ETH");
      buyUniswapPool(address(_poolToken), _amount);
      poolReceivedAmount = _amount;
      connectorsSpended = _connectorsAmount;
    }
    else{
      // unknown portal type
      revert("unknown portal type");
    }
  }


  function getBancorConnectorsByRelay(address relay)
  public
  view
  returns(address[] memory connectorsAddress)
  {
    connectorsAddress = new address[](2);
    connectorsAddress[0] = BNT;
    connectorsAddress[1] = DAI;
  }

  function getUniswapConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
  public
  view
  returns(uint256 ethAmount, uint256 ercAmount){
    ethAmount = _amount.div(2);
    ercAmount = _amount.div(2);
  }


  function getTokenByUniswapExchange(address _exchange)
  public
  view
  returns(address){
    return DAI;
  }


  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    bytes32[] memory _additionalArgs,
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
    connectorsAddress = new address[](2);
    connectorsAmount = new uint256[](2);

    if(_type == uint(PortalType.Bancor)){
      if(address(_poolToken) == ETHBNT){
        connectorsAddress[0] = BNT;
        connectorsAddress[1] = address(ETH_TOKEN_ADDRESS);
        sellETHPoolViaBancor(_poolToken, _amount);
      }else{
        connectorsAddress[0] = BNT;
        connectorsAddress[1] = DAI;
        sellPoolViaBancor(_poolToken, _amount);
      }
    }
    else if (_type == uint(PortalType.Uniswap)){
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = DAI;
      sellPoolViaUniswap(_poolToken, _amount);
    }
    else{
      // unknown portal type
      revert();
    }

    // return mock data
    connectorsAmount[0] = _amount.div(2);
    connectorsAmount[1] = _amount.div(2);
    poolAmountSent = _amount;
  }


  function getDataForBuyingPool(IERC20 _poolToken, uint _type, uint256 _amount)
    external
    view
    returns(
      address[] memory connectorsAddress,
      uint256[] memory connectorsAmount
  )
  {
    connectorsAddress = new address[](2);
    connectorsAmount = new uint256[](2);

    if(_type == uint(PortalType.Bancor)){
      // return mock data
      connectorsAddress[0] = BNT;
      connectorsAddress[1] = DAI;
      connectorsAmount[0] = _amount.div(2);
      connectorsAmount[1] = _amount.div(2);
    }
    else if(_type == uint(PortalType.Uniswap)){

      // return mock data
      connectorsAddress[0] = address(ETH_TOKEN_ADDRESS);
      connectorsAddress[1] = DAI;
      connectorsAmount[0] = _amount;
      connectorsAmount[1] = _amount;
    }
    else {
      revert("Unknown pool type");
    }
  }


  function sellPoolViaBancor(IERC20 _poolToken, uint256 _amount) private {
    // get BNT pool relay back
    require(IERC20(DAIBNTPoolToken).transferFrom(msg.sender, address(this), _amount));

    // send back connectors
    require(IERC20(DAI).transfer(msg.sender, _amount.div(2)));
    require(IERC20(BNT).transfer(msg.sender, _amount.div(2)));
  }

  function sellETHPoolViaBancor(IERC20 _poolToken, uint256 _amount) private {
    // get BNT pool relay back
    require(IERC20(ETHBNT).transferFrom(msg.sender, address(this), _amount));

    // send back connectors
    payable(msg.sender).transfer(_amount.div(2));
    require(IERC20(BNT).transfer(msg.sender, _amount.div(2)));
  }

  function sellPoolViaUniswap(IERC20 _poolToken, uint256 _amount) private {
    // get UNI pool back
    require(IERC20(DAIUNIPoolToken).transferFrom(msg.sender, address(this), _amount));

    // send back connectors
    require(IERC20(DAI).transfer(msg.sender, _amount.div(2)));
    payable(address(msg.sender)).transfer(_amount.div(2));
  }

  // Pool portal can mark each pool token as UNISWAP or BANCOR
  function setTokenType(address _token, string memory _type) private {
    // no need add type, if token alredy registred
    if(tokensTypes.isRegistred(_token))
      return;

    tokensTypes.addNewTokenType(_token,  _type);
  }

  function pay() public payable {}

  fallback() external payable {}
}
