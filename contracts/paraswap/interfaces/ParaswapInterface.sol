interface ParaswapInterface{
  function swap(
     address sourceToken,
     address destinationToken,
     uint256 sourceAmount,
     uint256 minDestinationAmount,
     address[] calldata callees,
     bytes calldata exchangeData,
     uint256[] calldata startIndexes,
     uint256[] calldata values,
     string calldata referrer,
     uint256 mintPrice
   )
   external
   payable;

   function getTokenTransferProxy() external view returns (address);
}
