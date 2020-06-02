interface PathFinderInterface {
 function generatePath(address _sourceToken, address _targetToken) external view returns (address[] memory);
}
