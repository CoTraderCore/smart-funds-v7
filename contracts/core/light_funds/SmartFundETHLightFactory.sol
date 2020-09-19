pragma solidity ^0.6.12;

import "./SmartFundETHLight.sol";

contract SmartFundETHLightFactory {
  address public platfromAddress;

  constructor(address _platfromAddress) public {
    platfromAddress = _platfromAddress;
  }

  function createSmartFundLight(
    address _owner,
    string  memory _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _permittedAddresses,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundETHLight smartFundETHLight = new SmartFundETHLight(
      _owner,
      _name,
      _successFee,
      _platformFee,
      platfromAddress,
      _exchangePortalAddress,
      _permittedAddresses,
      _isRequireTradeVerification
    );

    return address(smartFundETHLight);
  }
}
