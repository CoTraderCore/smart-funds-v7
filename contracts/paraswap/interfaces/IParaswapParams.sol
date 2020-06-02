interface IParaswapParams{
  function getParaswapParamsFromBytes32Array(bytes32[] calldata _additionalArgs)
  external pure returns
  (
    uint256 minDestinationAmount,
    address[] memory callees,
    uint256[] memory startIndexes,
    uint256[] memory values,
    uint256 mintPrice
  );
}
