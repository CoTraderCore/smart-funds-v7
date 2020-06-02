pragma solidity ^0.4.24;

library addressFromBytes32 {

/**
* @dev Allows convert address from bytes32
*
* @param _address   bytes32 address
*/
function bytesToAddress(bytes32 _address) internal pure returns (address) {
 uint160 m = 0;
 uint160 b = 0;

 for (uint8 i = 0; i < 20; i++) {
   m *= 256;
   b = uint160(_address[i]);
   m += (b);
 }

 return address(m);
}
}
