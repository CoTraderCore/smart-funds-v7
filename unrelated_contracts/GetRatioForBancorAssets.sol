pragma solidity ^0.4.24;

import "../contracts/bancor/interfaces/PathFinderInterface.sol";
import "../contracts/bancor/interfaces/BancorNetworkInterface.sol";
import "../contracts/bancor/interfaces/IGetBancorAddressFromRegistry.sol";

pragma solidity ^0.4.24;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * See https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}




/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender)
    public view returns (uint256);

  function transferFrom(address from, address to, uint256 value)
    public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}


contract GetRatioForBancorAssets {
  IGetBancorAddressFromRegistry public bancorRegistry;

  /**
  * @dev contructor
  *
  * @param bancorRegistryWrapper  address of GetBancorAddressFromRegistry
  */
  constructor(address bancorRegistryWrapper) public{
    bancorRegistry = IGetBancorAddressFromRegistry(bancorRegistryWrapper);
  }


  /**
  * @dev get ratio between Bancor assets
  *
  * @param _from  ERC20 or Relay
  * @param _to  ERC20 or Relay
  * @param _amount  amount for _from
  */
  function getRatio(address _from, address _to, uint256 _amount) public view returns(uint256 result){
    if(_amount > 0){
      // get latest contracts
      PathFinderInterface pathFinder = PathFinderInterface(
        bancorRegistry.getBancorContractAddresByName("BancorNetworkPathFinder")
      );

      BancorNetworkInterface bancorNetwork = BancorNetworkInterface(
        bancorRegistry.getBancorContractAddresByName("BancorNetwork")
      );

      // get Bancor path array
      address[] memory path = pathFinder.generatePath(_from, _to);
      ERC20[] memory pathInERC20 = new ERC20[](path.length);

      // Convert addresses to ERC20
      for(uint i=0; i<path.length; i++){
          pathInERC20[i] = ERC20(path[i]);
      }

      // get Ratio
      ( uint256 ratio, ) = bancorNetwork.getReturnByPath(pathInERC20, _amount);
      result = ratio;
    }
    else{
      result = 0;
    }
  }
}
