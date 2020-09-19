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
    address _exchangePortalAddress,
    address _poolPortalAddress,
    address _defiPortal,
    address _permittedAddresses,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  public
  returns(address)
  {
    SmartFundERC20 smartFundERC20 = new SmartFundERC20(
      _owner,
      _name,
      _successFee,
       platfromAddress,
      _exchangePortalAddress,
      _poolPortalAddress,
      _defiPortal,
      _permittedAddresses,
      _coinAddress,
      _isRequireTradeVerification
    );

    return address(smartFundERC20);
  }
}
