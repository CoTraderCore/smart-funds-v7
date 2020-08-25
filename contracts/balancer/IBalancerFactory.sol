interface IBalancerFactory {
  function isBPool(address b) external view returns (bool);
  function newBPool() external returns (BPool);
}
