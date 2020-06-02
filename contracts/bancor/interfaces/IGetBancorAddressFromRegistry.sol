interface IGetBancorAddressFromRegistry {
  function getBancorContractAddresByName(string calldata _name) external view returns (address result);
}
