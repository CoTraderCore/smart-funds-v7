interface DefiPortalInterface {
  function callPayableProtocol(
    bytes calldata _data,
    bytes32[] calldata _additionalArgs
  )
    external
    payable
    returns(
      string memory eventType,
      address[] memory tokensSent,
      address[] memory tokensReceived,
      uint256[] memory amountSent,
      uint256[] memory amountReceived
    );

  function callNonPayableProtocol(
    bytes calldata _data,
    bytes32[] calldata _additionalArgs
  )
    external
    returns(
      string memory eventType,
      address[] memory tokensSent,
      address[] memory tokensReceived,
      uint256[] memory amountSent,
      uint256[] memory amountReceived
    );
}
