// JUST FOR TEST MATH Directly
// NO NEED DEPLOY this with platform 

pragma solidity ^0.4.24;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * See https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


contract PoolPortalInterface {
  function buyPool
  (
    uint256 _amount,
    uint _type,
    ERC20 _poolToken,
    bytes32[] _additionalArgs
  )
  external
  payable;

  function sellPool
  (
    uint256 _amount,
    uint _type,
    ERC20 _poolToken,
    bytes32[] _additionalArgs
  )
  external
  payable;

  function getBacorConverterAddressByRelay(address relay) public view returns(address converter);

  function getBancorConnectorsByRelay(address relay)
  public
  view
  returns(
    ERC20 BNTConnector,
    ERC20 ERCConnector
  );

  function getRatio(address _from, address _to, uint256 _amount) public view returns(uint256);
  function getTotalValue(address[] _fromAddresses, uint256[] _amounts, address _to) public view returns (uint256);
}


contract ExchangePortalInterface {

  event Trade(address src, uint256 srcAmount, address dest, uint256 destReceived);

  function trade(
    ERC20 _source,
    uint256 _sourceAmount,
    ERC20 _destination,
    uint256 _type,
    bytes32[] _additionalArgs,
    bytes _additionalData
  )
    external
    payable
    returns (uint256);

  function getValue(address _from, address _to, uint256 _amount) public view returns (uint256);
  function getTotalValue(address[] _fromAddresses, uint256[] _amounts, address _to) public view returns (uint256);
}





/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender)
    public view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}


contract smartFundTestMATH {

  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;

  // KyberExchange recognizes ETH by this address
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

  // The Interface of pool portall
  PoolPortalInterface public poolPortal;

  // The Interface of the Exchange Portal
  ExchangePortalInterface public exchangePortal;

  // mapping for check is relay or not
  mapping(address => bool) public isRelay;



  constructor(
    address _exchangePortalAddress,
    address _poolPortal
  ) public {


    // Initial Token is Ether
    tokenAddresses.push(address(ETH_TOKEN_ADDRESS));

    // Initial interfaces
    exchangePortal = ExchangePortalInterface(_exchangePortalAddress);
    poolPortal = PoolPortalInterface(_poolPortal);
  }


  /**
  * @dev Calculates the funds value in deposit token (Ether)
  *
  * @return The current total fund value
  */
  function calculateFundValue() public view returns (uint256) {
    uint256 ethBalance = address(this).balance;

    // If the fund only contains ether, return the funds ether balance
    if (tokenAddresses.length == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddresses.length - 1);
    uint256[] memory amounts = new uint256[](tokenAddresses.length - 1);

    for (uint256 i = 1; i < tokenAddresses.length; i++) {
      fromAddresses[i-1] = tokenAddresses[i];
      amounts[i-1] = ERC20(tokenAddresses[i]).balanceOf(address(this));
    }

    // Ask the Exchange Portal for the value of all the funds tokens in eth
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, ETH_TOKEN_ADDRESS);

    // Sum ETH + ERC20
    return ethBalance + tokensValue;
  }


  function _addToken(address _token) public {
    tokenAddresses.push(_token);
  }

  function _addRelay(address _relay) public {
    isRelay[_relay] = true;
  }

  // Fallback payable function in order to be able to receive ether from other contracts
  function() public payable {}
}
