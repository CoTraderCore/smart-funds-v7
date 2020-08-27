interface SmartFundUSDFactoryInterface {
  function createSmartFund(
    address _owner,
    string  calldata _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _exchangePortalAddress,
    address _permittedExchanges,
    address _permittedPools,
    address _permittedStabels,
    address _poolPortalAddress,
    address _сoinAddress,
    address _cEther,
    bool    _isRequireTradeVerification
    )
  external
  returns(address);
}
