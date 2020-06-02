interface ConvertPortalInterface {
  function convert(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    address _receiver
    )
    external
    payable;
}
