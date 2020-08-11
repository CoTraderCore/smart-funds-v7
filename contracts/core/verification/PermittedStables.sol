pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/access/Ownable.sol";

/*
  The PermittedStables contract determines which addresses are permitted
*/
contract PermittedStables is Ownable {
  event NewStablesEnabled(address newStable, bool enabled);
  // Mapping to permitted stable coin addresses
  mapping (address => bool) public permittedAddresses;

  /**
  * @dev contructor
  *
  * @param _address    The initial stable coin address to be permitted
  */
  constructor(address _address) public {
    _enableAddress(_address, true);
  }


  /**
  * @dev Completes the process of adding a new stable coin to permittedAddresses
  *
  * @param _newAddress    The new address to permit
  */
  function addNewStableAddress(address _newAddress) public onlyOwner {
    // Set the stable coin as permitted
    _enableAddress(_newAddress, true);
  }

  /**
  * @dev Disables an address, meaning SmartFunds will no longer be able to connect to them
  * if they're not already connected
  *
  * @param _newAddress    The address to disable
  */
  function disableAddress(address _newAddress) public onlyOwner {
    _enableAddress(_newAddress, false);
  }

  /**
  * @dev Enables/disables an address
  *
  * @param _newAddress    The new address to set
  * @param _enabled       Bool representing whether or not the address will be enabled
  */
  function _enableAddress(address _newAddress, bool _enabled) private {
    permittedAddresses[_newAddress] = _enabled;

    emit NewStablesEnabled(_newAddress, _enabled);
  }
}
