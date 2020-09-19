interface SmartFundERC20LightFactoryInterface {
  function createSmartFundLight(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _exchangePortalAddress,
    address _permittedAddresses,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  external
  returns(address);
}
