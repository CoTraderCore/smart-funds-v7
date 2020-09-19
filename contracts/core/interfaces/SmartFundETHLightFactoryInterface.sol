interface SmartFundETHLightFactoryInterface {
  function createSmartFundLight(
    address _owner,
    string  memory _name,
    uint256 _successFee,
    address _exchangePortalAddress,
    address _permittedAddresses,
    bool    _isRequireTradeVerification
  )
  external
  returns(address);
}
