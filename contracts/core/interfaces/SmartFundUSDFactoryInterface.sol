interface SmartFundUSDFactoryInterface {
  function createSmartFund(
    address _owner,
    string  calldata _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _platfromAddress,
    address _exchangePortalAddress,
    address _permittedExchanges,
    address _permittedPools,
    address _permittedStabels,
    address _poolPortalAddress,
    address _stableCoinAddress,
    address _cEther,
    address _permittedConvertsAddress
    )
  external
  returns(address);
}
