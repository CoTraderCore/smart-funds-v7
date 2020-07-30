interface SmartTokenInterface {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function disableTransfers(bool _disable) external;
  function issue(address _to, uint256 _amount) external;
  function destroy(address _from, uint256 _amount) external;
  function owner() external view returns (address);
}
