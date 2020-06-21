pragma solidity ^0.4.24;

import "../bancor/interfaces/IContractRegistry.sol";
import "./helpers/stringToBytes32.sol";
import "../zeppelin-solidity/contracts/ownership/Ownable.sol";

contract GetBancorAddressFromRegistry is Ownable{
  using stringToBytes32 for string;
  IContractRegistry public bancorRegistry;

  constructor(address _bancorRegistry)public{
    bancorRegistry = IContractRegistry(_bancorRegistry);
  }

  // return contract address from Bancor registry by name
  function getBancorContractAddresByName(string _name) public view returns (address result){
     bytes32 name = stringToBytes32.convert(_name);
     result = bancorRegistry.addressOf(name);
  }

  function changeRegistryAddress(address _bancorRegistry) public onlyOwner{
    bancorRegistry = IContractRegistry(_bancorRegistry);
  }
}
