import "./CToken.sol";

interface CEther{
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint() external payable;
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow() external payable;
    function liquidateBorrow(address borrower, CToken cTokenCollateral) external payable;
    function exchangeRateCurrent() external returns (uint);
    function exchangeRateStored() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOfUnderlying(address account) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
}
