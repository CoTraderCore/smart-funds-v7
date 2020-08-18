import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface BancorConverterInterfaceV2 {
  function addLiquidity(address _reserveToken, uint256 _amount, uint256 _minReturn) external payable;
  function removeLiquidity(address _poolToken, uint256 _amount, uint256 _minReturn) external;

  function poolToken(address _reserveToken) external view returns(address);
  function connectorTokenCount() external view returns (uint16);
  function connectorTokens(uint index) external view returns(IERC20);
}
