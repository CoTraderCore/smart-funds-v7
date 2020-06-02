interface IGetRatioForBancorAssets {
  function getRatio(address _from, address _to, uint256 _amount) external view returns(uint256 result);
}
