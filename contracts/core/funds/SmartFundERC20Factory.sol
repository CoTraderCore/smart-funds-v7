pragma solidity ^0.6.12;

import "./SmartFundERC20.sol";

contract SmartFundERC20Factory {
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
    address _cEther,
    bool    _isRequireTradeVerification
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
      _cEther,
      _isRequireTradeVerification
    );

    return address(smartFundUSD);
  }
}
