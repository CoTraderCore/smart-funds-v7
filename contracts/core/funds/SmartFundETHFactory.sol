pragma solidity ^0.6.12;

import "./SmartFundETH.sol";

contract SmartFundETHFactory {
  address public platfromAddress;

  constructor(address _platfromAddress) public {
    platfromAddress = _platfromAddress;
  }

  function createSmartFund(
    address _owner,
    string  memory _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _permittedExchanges,
    address _permittedPools,
    address _defiPortal,
    address _permittedDefiPortalAddress,
    address _poolPortalAddress,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundETH smartFundETH = new SmartFundETH(
      _owner,
      _name,
      _successFee,
      _platformFee,
      platfromAddress,
      _exchangePortalAddress,
      _permittedExchanges,
      _permittedPools,
      _poolPortalAddress,
      _defiPortal,
      _permittedDefiPortalAddress,
      _isRequireTradeVerification
    );

    return address(smartFundETH);
  }
}
