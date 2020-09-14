pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/access/Ownable.sol";

/*
  The PermittedDefi contract determines which depi portal addresses are permitted
*/
contract PermittedDefi is Ownable {
  event NewDefiPortalEnabled(address newDefi, bool enabled);

  // Mapping to permitted DefiPortal addresses
  mapping (address => bool) public permittedAddresses;

  /**
  * @dev contructor
  *
  * @param _address    The initial defi portal address to be permitted
  */
  constructor(address _address) public {
    _enableAddress(_address, true);
  }


  /**
  * @dev Completes the process of adding a new defi portal to permittedAddresses
  *
  * @param _newAddress    The new address to permit
  */
  function addNewDefiPortalAddress(address _newAddress) public onlyOwner {
    // Set the defi portal as permitted
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

    emit NewDefiPortalEnabled(_newAddress, _enabled);
  }
}
