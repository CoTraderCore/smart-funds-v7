import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface BancorConverterInterfaceV2 {

  function addLiquidity(
    IERC20[] calldata _reserveTokens,
    uint256[] calldata _reserveAmounts,
    uint256 _minReturn) external payable;

  function removeLiquidity(
    uint256 _amount,
    IERC20[] calldata _reserveTokens,
    uint256[] calldata _reserveMinReturnAmounts) external;
}
