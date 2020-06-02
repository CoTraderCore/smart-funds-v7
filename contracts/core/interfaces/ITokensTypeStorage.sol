interface ITokensTypeStorage {
  function isRegistred(address _address) external view returns(bool);

  function getType(address _address) external view returns(bytes32);

  function isPermittedAddress(address _address) external view returns(bool);

  function owner() external view returns(address);

  function addNewTokenType(address _token, string calldata _type) external;

  function setTokenTypeAsOwner(address _token, string calldata _type) external;
}
