interface PermittedAddressesInterface {
  function permittedAddresses(address _address) external view returns(bool);
  function addressesTypes(address _address) external view returns(string memory);
}
