interface DefiPortalInterface {
  function callPayableProtocol(
    bytes calldata _data,
    bytes32[] calldata _additionalArgs
  )
    external
    payable
    returns(
      string memory eventType,
      address[] memory tokensToReceive,
      uint256[] memory amountsToReceive
    );

  function callNonPayableProtocol(
    bytes calldata _data,
    bytes32[] calldata _additionalArgs
  )
    external
    returns(
      string memory eventType,
      address[] memory tokensToReceive,
      uint256[] memory amountsToReceive
    );

  function getValue(
    address _from,
    address _to,
    uint256 _amount
  )
   external
   view
   returns(uint256);
}
