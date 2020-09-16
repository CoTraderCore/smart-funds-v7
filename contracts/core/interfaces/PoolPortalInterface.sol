interface PoolPortalInterface {
  function buyPool
  (
    uint256 _amount,
    uint _type,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  payable
  returns(uint256 poolAmountReceive, uint256[] memory connectorsSpended);

  function sellPool
  (
    uint256 _amount,
    uint _type,
    address _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionData
  )
  external
  payable
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  );
}
