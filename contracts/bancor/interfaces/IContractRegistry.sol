interface IContractRegistry {
    function addressOf(bytes32 _contractName) external view returns (address);
    // deprecated, backward compatibility
    function getAddress(bytes32 _contractName) external view returns (address);
}
