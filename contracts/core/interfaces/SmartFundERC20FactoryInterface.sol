interface SmartFundERC20FactoryInterface {
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
  external
  returns(address);
}
