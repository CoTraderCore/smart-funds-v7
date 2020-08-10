import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface BancorConverterInterfaceV2 {
  function addLiquidity(address _reserveToken, uint256 _amount) external payable;
  function removeLiquidity(address _poolToken, uint256 _amount) external;

  function connectorTokenCount() external view returns (uint16);
  function connectorTokens(uint index) external view returns(IERC20);
}
