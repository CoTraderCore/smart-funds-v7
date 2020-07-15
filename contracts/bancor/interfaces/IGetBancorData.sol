import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface IGetBancorData {
  function getBancorContractAddresByName(string calldata _name) external view returns (address result);
  function getBancorRatioForAssets(IERC20 _from, IERC20 _to, uint256 _amount) external view returns(uint256 result);
  function getBancorPathForAssets(IERC20 _from, IERC20 _to) external view returns(address[] memory);
}
