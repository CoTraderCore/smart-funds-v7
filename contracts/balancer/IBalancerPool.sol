interface IBalancerPool {
    function joinPool(uint poolAmountOut, uint[] calldata maxAmountsIn) external;
    function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external;
    function getCurrentTokens() external view returns (address[] memory tokens);
}
