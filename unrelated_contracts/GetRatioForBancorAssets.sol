pragma solidity ^0.4.24;

interface IGetBancorAddressFromRegistry {
  function getBancorContractAddresByName(string _name) external view returns (address result);
}


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface ERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/*
    Bancor Network interface
*/
interface BancorNetworkInterface {
   function getReturnByPath(
     ERC20[] _path,
     uint256 _amount)
     external
     view
     returns (uint256, uint256);

    function convert(
        ERC20[] _path,
        uint256 _amount,
        uint256 _minReturn
    ) external payable returns (uint256);

    function claimAndConvert(
        ERC20[]  _path,
        uint256 _amount,
        uint256 _minReturn
    ) external returns (uint256);

    function convertFor(
        ERC20[]  _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for
    ) external payable returns (uint256);

    function claimAndConvertFor(
        ERC20[]  _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for
    ) external returns (uint256);

    function conversionPath(
        IERC20 _sourceToken,
        IERC20 _targetToken
    ) external view returns (address[]);
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
      BancorNetworkInterface bancorNetwork = BancorNetworkInterface(
        bancorRegistry.getBancorContractAddresByName("BancorNetwork")
      );

      // get Bancor path array
      address[] memory path = bancorNetwork.conversionPath(_from, _to);
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
