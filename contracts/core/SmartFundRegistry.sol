pragma solidity ^0.6.12;

import "./interfaces/SmartFundETHFactoryInterface.sol";
import "./interfaces/SmartFundERC20FactoryInterface.sol";
import "./interfaces/SmartFundETHLightFactoryInterface.sol";
import "./interfaces/SmartFundERC20LightFactoryInterface.sol";

import "./interfaces/PermittedAddressesInterface.sol";

import "../zeppelin-solidity/contracts/access/Ownable.sol";
import "../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";


/*
* The SmartFundRegistry is used to manage the creation and permissions of SmartFund contracts
*/
contract SmartFundRegistry is Ownable {
  address[] public smartFunds;

  // The Smart Contract which stores the addresses of all the authorized address
  PermittedAddressesInterface public permittedAddresses;

  // Addresses of portals
  address public poolPortalAddress;
  address public exchangePortalAddress;
  address public defiPortalAddress;

  // Default maximum success fee is 3000/30%
  uint256 public maximumSuccessFee = 3000;

  // Address of stable coin can be set in constructor and changed via function
  address public stableCoinAddress;

  // Address of CoTrader coin be set in constructor
  address public COTCoinAddress;

  // Factories
  SmartFundETHFactoryInterface public smartFundETHFactory;
  SmartFundERC20FactoryInterface public smartFundERC20Factory;
  SmartFundETHLightFactoryInterface public smartFundETHLightFactory;
  SmartFundERC20LightFactoryInterface public smartFundERC20LightFactory;

  // Enum for detect fund type in create fund function
  // NOTE: You can add a new type at the end, but do not change this order
  enum FundType { ETH, USD, COT }

  event SmartFundAdded(address indexed smartFundAddress, address indexed owner);

  /**
  * @dev contructor
  *
  * @param _exchangePortalAddress        Address of the initial ExchangePortal contract
  * @param _poolPortalAddress            Address of the initial PoolPortal contract
  * @param _stableCoinAddress            Address of the stable coin
  * @param _COTCoinAddress               Address of Cotrader coin
  * @param _smartFundETHFactory          Address of smartFund ETH factory
  * @param _smartFundERC20Factory        Address of smartFund USD factory
  * @param _smartFundETHLightFactory     Address of smartFund ETH factory
  * @param _smartFundERC20LightFactory   Address of smartFund USD factory
  * @param _defiPortalAddress            Address of defiPortal contract
  * @param _permittedAddresses           Address of permittedAddresses contract
  */
  constructor(
    address _exchangePortalAddress,
    address _poolPortalAddress,
    address _stableCoinAddress,
    address _COTCoinAddress,
    address _smartFundETHFactory,
    address _smartFundERC20Factory,
    address _smartFundETHLightFactory,
    address _smartFundERC20LightFactory,
    address _defiPortalAddress,
    address _permittedAddresses
  ) public {
    exchangePortalAddress = _exchangePortalAddress;
    poolPortalAddress = _poolPortalAddress;
    stableCoinAddress = _stableCoinAddress;
    COTCoinAddress = _COTCoinAddress;
    smartFundETHFactory = SmartFundETHFactoryInterface(_smartFundETHFactory);
    smartFundERC20Factory = SmartFundERC20FactoryInterface(_smartFundERC20Factory);
    smartFundETHLightFactory = SmartFundETHLightFactoryInterface(_smartFundETHLightFactory);
    smartFundERC20LightFactory = SmartFundERC20LightFactoryInterface(_smartFundERC20LightFactory);
    defiPortalAddress = _defiPortalAddress;
    permittedAddresses = PermittedAddressesInterface(_permittedAddresses);
  }

  /**
  * @dev Creates a new Full SmartFund
  *
  * @param _name                        The name of the new fund
  * @param _successFee                  The fund managers success fee
  * @param _fundType                    Fund type enum number
  * @param _isRequireTradeVerification  If true fund can buy only tokens,
  *                                     which include in Merkle Three white list
  */
  function createSmartFund(
    string memory _name,
    uint256       _successFee,
    uint256       _fundType,
    bool          _isRequireTradeVerification
  ) public {
    // Require that the funds success fee be less than the maximum allowed amount
    require(_successFee <= maximumSuccessFee);

    address smartFund;

    // ETH case
    if(_fundType == uint256(FundType.ETH)){
      // Create ETH Fund
      smartFund = smartFundETHFactory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        exchangePortalAddress,
        poolPortalAddress,
        defiPortalAddress,
        address(permittedAddresses),
        _isRequireTradeVerification
      );

    }
    // ERC20 case
    else{
      address coinAddress = getERC20AddressByFundType(_fundType);
      // Create ERC20 based fund
      smartFund = smartFundERC20Factory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        exchangePortalAddress,
        poolPortalAddress,
        defiPortalAddress,
        address(permittedAddresses),
        coinAddress,
        _isRequireTradeVerification
      );
    }

    smartFunds.push(smartFund);
    emit SmartFundAdded(smartFund, msg.sender);
  }

  /**
  * @dev Creates a new Light SmartFund
  *
  * @param _name                        The name of the new fund
  * @param _successFee                  The fund managers success fee
  * @param _fundType                    Fund type enum number
  * @param _isRequireTradeVerification  If true fund can buy only tokens,
  *                                     which include in Merkle Three white list
  */
  function createSmartFundLight(
    string memory _name,
    uint256       _successFee,
    uint256       _fundType,
    bool          _isRequireTradeVerification
  ) public {
    // Require that the funds success fee be less than the maximum allowed amount
    require(_successFee <= maximumSuccessFee);

    address smartFund;

    // ETH case
    if(_fundType == uint256(FundType.ETH)){
      // Create ETH Fund
      smartFund = smartFundETHLightFactory.createSmartFundLight(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        exchangePortalAddress,
        address(permittedAddresses),
        _isRequireTradeVerification
      );

    }
    // ERC20 case
    else{
      address coinAddress = getERC20AddressByFundType(_fundType);
      // Create ERC20 based fund
      smartFund = smartFundERC20LightFactory.createSmartFundLight(
        msg.sender,
        _name,
        _successFee, // manager and platform fee
        exchangePortalAddress,
        address(permittedAddresses),
        coinAddress,
        _isRequireTradeVerification
      );
    }

    smartFunds.push(smartFund);
    emit SmartFundAdded(smartFund, msg.sender);
  }


  function getERC20AddressByFundType(uint256 _fundType) private view returns(address coinAddress){
    // Define coin address dependse of fund type
    coinAddress = _fundType == uint256(FundType.USD)
    ? stableCoinAddress
    : COTCoinAddress;
  }

  function totalSmartFunds() public view returns (uint256) {
    return smartFunds.length;
  }

  function getAllSmartFundAddresses() public view returns(address[] memory) {
    address[] memory addresses = new address[](smartFunds.length);

    for (uint i; i < smartFunds.length; i++) {
      addresses[i] = address(smartFunds[i]);
    }

    return addresses;
  }

  /**
  * @dev Owner can set a new default ExchangePortal address
  *
  * @param _newExchangePortalAddress    Address of the new exchange portal to be set
  */
  function setExchangePortalAddress(address _newExchangePortalAddress) external onlyOwner {
    // Require that the new exchange portal is permitted by permittedAddresses
    require(permittedAddresses.permittedAddresses(_newExchangePortalAddress));

    exchangePortalAddress = _newExchangePortalAddress;
  }

  /**
  * @dev Owner can set a new default Portal Portal address
  *
  * @param _poolPortalAddress    Address of the new pool portal to be set
  */
  function setPoolPortalAddress(address _poolPortalAddress) external onlyOwner {
    // Require that the new pool portal is permitted by permittedAddresses
    require(permittedAddresses.permittedAddresses(_poolPortalAddress));

    poolPortalAddress = _poolPortalAddress;
  }

  /**
  * @dev Allows the fund manager to connect to a new permitted defi portal
  *
  * @param _newDefiPortalAddress    The address of the new permitted defi portal to use
  */
  function setDefiPortal(address _newDefiPortalAddress) public onlyOwner {
    // Require that the new defi portal is permitted by permittedAddresses
    require(permittedAddresses.permittedAddresses(_newDefiPortalAddress));

    defiPortalAddress = _newDefiPortalAddress;
  }

  /**
  * @dev Owner can set maximum success fee for all newly created SmartFunds
  *
  * @param _maximumSuccessFee    New maximum success fee
  */
  function setMaximumSuccessFee(uint256 _maximumSuccessFee) external onlyOwner {
    maximumSuccessFee = _maximumSuccessFee;
  }

  /**
  * @dev Owner can set new stableCoinAddress
  *
  * @param _stableCoinAddress    New stable address
  */
  function setStableCoinAddress(address _stableCoinAddress) external onlyOwner {
    require(permittedAddresses.permittedAddresses(_stableCoinAddress));
    stableCoinAddress = _stableCoinAddress;
  }


  /**
  * @dev Owner can set new smartFundETHFactory
  *
  * @param _smartFundETHFactory    address of ETH factory contract
  */
  function setNewSmartFundETHFactory(address _smartFundETHFactory) external onlyOwner {
    smartFundETHFactory = SmartFundETHFactoryInterface(_smartFundETHFactory);
  }


  /**
  * @dev Owner can set new smartFundERC20Factory
  *
  * @param _smartFundERC20Factory    address of ERC20 factory contract
  */
  function setNewSmartFundERC20Factory(address _smartFundERC20Factory) external onlyOwner {
    smartFundERC20Factory = SmartFundERC20FactoryInterface(_smartFundERC20Factory);
  }


  /**
  * @dev Owner can set new smartFundETHLightFactory
  *
  * @param _smartFundETHLightFactory    address of ETH factory contract
  */
  function setNewSmartFundETHLightFactory(address _smartFundETHLightFactory) external onlyOwner {
      smartFundETHLightFactory = SmartFundETHLightFactoryInterface(_smartFundETHLightFactory);
  }

  /**
  * @dev Owner can set new smartFundERC20LightFactory
  *
  * @param _smartFundERC20LightFactory    address of ERC20 factory contract
  */
  function setNewSmartFundERC20LightFactory(address _smartFundERC20LightFactory) external onlyOwner {
    smartFundERC20LightFactory = SmartFundERC20LightFactoryInterface(_smartFundERC20LightFactory);
  }

  /**
  * @dev Allows withdarw tokens from this contract if someone will accidentally send tokens here
  *
  * @param _tokenAddress    Address of the token to be withdrawn
  */
  function withdrawTokens(address _tokenAddress) external onlyOwner {
    IERC20 token = IERC20(_tokenAddress);
    token.transfer(owner(), token.balanceOf(address(this)));
  }

  /**
  * @dev Allows withdarw ETH from this contract if someone will accidentally send tokens here
  */
  function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  // Fallback payable function in order to receive ether when fund manager withdraws their cut
  fallback() external payable {}

}
