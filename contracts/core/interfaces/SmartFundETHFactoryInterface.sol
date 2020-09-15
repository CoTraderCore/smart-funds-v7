interface SmartFundETHFactoryInterface {
  function createSmartFund(
    address _owner,
    string  memory _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _poolPortalAddress,
    address _defiPortal,
    address _permittedAddresses,
    bool    _isRequireTradeVerification
  )
  external
  returns(address);
}
