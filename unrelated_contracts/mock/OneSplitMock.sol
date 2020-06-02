// NO NEED FOR MAINNET
// THIS need ONLY FOR ROPSTEN test!!!
pragma solidity ^0.4.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract OneSplitMock {
  function getExpectedReturn(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 parts,
        uint256 featureFlags // See contants in IOneSplit.sol
    )
    public
    view
    returns(
        uint256 returnAmount,
        uint256[] memory distribution
    )
    {
      returnAmount = amount;
      distribution = new uint256[](2);
      distribution[0] = 1;
      distribution[1] = 1;
    }
}
