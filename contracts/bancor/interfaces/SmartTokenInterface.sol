import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface SmartTokenInterface is IERC20 {
  function disableTransfers(bool _disable) external;
  function issue(address _to, uint256 _amount) external;
  function destroy(address _from, uint256 _amount) external;
  function owner() external view returns (address);
}
