interface SmartFundETHFactoryInterface {
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
  external
  returns(address);
}
