// NO NEED FOR MAINNET
// THIS need for getBestPriceSimple function ONLY FOR ROPSTEN!!!
// FOR Bancor ropsten assets!


pragma solidity ^0.4.24;

import "../bancor/interfaces/IGetBancorAddressFromRegistry.sol";
import "../zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../bancor/interfaces/PathFinderInterface.sol";
import "../bancor/interfaces/BancorNetworkInterface.sol";

contract paraswapIFEEDMOCK{
  IGetBancorAddressFromRegistry public bancorRegistry;
  address public BancorEtherToken;
  ERC20 constant private ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

  /**
  * @dev contructor
  *
  * @param bancorRegistryWrapper  address of GetBancorAddressFromRegistry
  * @param _BancorEtherToken  address of Bancor ETH wrapper
  */
  constructor(address bancorRegistryWrapper, address _BancorEtherToken) public{
    bancorRegistry = IGetBancorAddressFromRegistry(bancorRegistryWrapper);
    BancorEtherToken = _BancorEtherToken;
  }


  function getRealPriceFromBancor(address _from, address _to, uint256 _amount) public view returns(uint256 result){
   // get latest contracts
   PathFinderInterface pathFinder = PathFinderInterface(
     bancorRegistry.getBancorContractAddresByName("BancorNetworkPathFinder")
   );

   BancorNetworkInterface bancorNetwork = BancorNetworkInterface(
     bancorRegistry.getBancorContractAddresByName("BancorNetwork")
   );

   // Change dest to Bancor ETH wrapper
   address dest = ERC20(_to) == ETH_TOKEN_ADDRESS ? BancorEtherToken : _to;

   // get Bancor path array
   address[] memory path = pathFinder.generatePath(_from, dest);

   // return mock if empty array
   if(path.length == 0) return 0;

   ERC20[] memory pathInERC20 = new ERC20[](path.length);

   // Convert addresses to ERC20
   for(uint i=0; i<path.length; i++){
       pathInERC20[i] = ERC20(path[i]);
   }

   // try get real price 
   (bool success) = address(bancorNetwork).call(
   abi.encodeWithSelector(bancorNetwork.getReturnByPath.selector, pathInERC20, _amount));

   if(success){
     // get Ratio
     ( uint256 ratio, ) = bancorNetwork.getReturnByPath(pathInERC20, _amount);

     result = ratio;
   }
   else{
     return 0;
   }
 }


  /**
  * @dev get ratio between Bancor assets
  *
  * @param _from  ERC20 or Relay
  * @param _to  ERC20 or Relay
  * @param _amount  amount for _from
  */
  function getBestPriceSimple(address _from, address _to, uint256 _amount) public view returns(uint256 result){
    if(_amount > 0){
      // Try get real pricefrom Bancor
      uint256 ratio = getRealPriceFromBancor(_from, _to, _amount);

      if(ratio > 0){
        result = getRealPriceFromBancor(_from, _to, _amount);
      }else{
        // return mock price
        result = _amount;
      }
    }
    else{
      result = 0;
    }
  }
}
