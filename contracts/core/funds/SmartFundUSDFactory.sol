// due eip-170 error we should create 2 factory one for ETH another for USD
pragma solidity ^0.6.0;

import "./SmartFundUSD.sol";

contract SmartFundUSDFactory {
  address public platfromAddress;

  constructor(address _platfromAddress) public {
    platfromAddress = _platfromAddress;
  }

  function createSmartFund(
    address _owner,
    string memory _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _permittedExchanges,
    address _permittedPools,
    address _permittedStables,
    address _poolPortalAddress,
    address _stableCoinAddress,
    address _convertPortalAddress,
    address _cEther,
    address _permittedConvertsAddress
    )
  public
  returns(address)
  {
    SmartFundUSD smartFundUSD = new SmartFundUSD(
      _owner,
      _name,
      _successFee,
      _platformFee,
       platfromAddress,
      _exchangePortalAddress,
      _permittedExchanges,
      _permittedPools,
      _permittedStables,
      _poolPortalAddress,
      _stableCoinAddress,
      _convertPortalAddress,
      _cEther,
      _permittedConvertsAddress
    );

    return address(smartFundUSD);
  }
}
