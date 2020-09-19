pragma solidity ^0.6.12;

import "./SmartFundERC20Light.sol";

contract SmartFundERC20LightFactory {
  address public platfromAddress;

  constructor(address _platfromAddress) public {
    platfromAddress = _platfromAddress;
  }

  function createSmartFundLight(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _exchangePortalAddress,
    address _permittedAddresses,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundERC20Light smartFundERC20Light = new SmartFundERC20Light(
      _owner,
      _name,
      _successFee,
       platfromAddress,
      _exchangePortalAddress,
      _permittedAddresses,
      _coinAddress,
      _isRequireTradeVerification
    );

    return address(smartFundERC20Light);
  }
}
