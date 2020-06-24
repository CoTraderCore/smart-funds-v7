import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface BancorConverterInterface {
  function connectorTokens(uint index) external view returns(IERC20);
  function fund(uint256 _amount) external;
  function liquidate(uint256 _amount) external;
  function getConnectorBalance(IERC20 _connectorToken) external view returns (uint256);
  function connectorTokenCount() external view returns (uint16);
}
