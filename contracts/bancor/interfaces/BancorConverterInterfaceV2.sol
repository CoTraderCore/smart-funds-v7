import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface BancorConverterInterfaceV2 {
  function addLiquidity(address _reserveToken, uint256 _amount) external;
  function removeLiquidity(address _poolToken, uint256 _amount) external;
}
