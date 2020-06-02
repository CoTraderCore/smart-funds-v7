import "../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface IOneSplitAudit {
  function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata distribution,
        uint256 disableFlags
    ) external payable;

  function getExpectedReturn(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 parts,
        uint256 featureFlags // See contants in IOneSplit.sol
    )
      external
      view
      returns(
          uint256 returnAmount,
          uint256[] memory distribution
      );
}
