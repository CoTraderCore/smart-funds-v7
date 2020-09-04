pragma solidity ^0.6.12;

import "./interfaces/SmartFundETHFactoryInterface.sol";
import "./interfaces/SmartFundERC20FactoryInterface.sol";
import "./interfaces/PermittedExchangesInterface.sol";
import "./interfaces/PermittedPoolsInterface.sol";
import "./interfaces/PermittedStablesInterface.sol";
import "./interfaces/PermittedConvertsInterface.sol";
import "../zeppelin-solidity/contracts/access/Ownable.sol";
import "../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
/*
* The SmartFundRegistry is used to manage the creation and permissions of SmartFund contracts
*/
contract SmartFundRegistry is Ownable {
  address[] public smartFunds;

  // The Smart Contract which stores the addresses of all the authorized Exchange Portals
  PermittedExchangesInterface public permittedExchanges;
  // The Smart Contract which stores the addresses of all the authorized Pool Portals
  PermittedPoolsInterface public permittedPools;
  // The Smart Contract which stores the addresses of all the authorized stable coins
  PermittedStablesInterface public permittedStables;

  // Addresses of portals
  address public poolPortalAddress;
  address public exchangePortalAddress;

  // Default maximum success fee is 3000/30%
  uint256 public maximumSuccessFee = 3000;

  // Address of stable coin can be set in constructor and changed via function
  address public stableCoinAddress;

  // Address of CoTrader coin be set in constructor
  address public COTCoinAddress;

  // Addresses for Compound platform
  address public cEther;

  // Factories
  SmartFundETHFactoryInterface public smartFundETHFactory;
  SmartFundERC20FactoryInterface public smartFundERC20Factory;

  // Enum for detect fund type in create fund function
  // NOTE: You can add a new type at the end, but do not change this order
  enum FundType { ETH, USD, COT }

  event SmartFundAdded(address indexed smartFundAddress, address indexed owner);

  /**
  * @dev contructor
  *
  * @param _permittedExchangesAddress    Address of the permittedExchanges contract
  * @param _exchangePortalAddress        Address of the initial ExchangePortal contract
  * @param _permittedPoolAddress         Address of the permittedPool contract
  * @param _poolPortalAddress            Address of the initial PoolPortal contract
  * @param _permittedStables             Address of the permittesStabels contract
  * @param _stableCoinAddress            Address of the stable coin
  * @param _COTCoinAddress               Address of Cotrader coin
  * @param _smartFundETHFactory          Address of smartFund ETH factory
  * @param _smartFundERC20Factory        Address of smartFund USD factory
  * @param _cEther                       Address of Compound ETH wrapper
  */
  constructor(
    address _permittedExchangesAddress,
    address _exchangePortalAddress,
    address _permittedPoolAddress,
    address _poolPortalAddress,
    address _permittedStables,
    address _stableCoinAddress,
    address _COTCoinAddress,
    address _smartFundETHFactory,
    address _smartFundERC20Factory,
    address _cEther
  ) public {
    exchangePortalAddress = _exchangePortalAddress;
    permittedExchanges = PermittedExchangesInterface(_permittedExchangesAddress);
    permittedPools = PermittedPoolsInterface(_permittedPoolAddress);
    permittedStables = PermittedStablesInterface(_permittedStables);
    poolPortalAddress = _poolPortalAddress;
    stableCoinAddress = _stableCoinAddress;
    COTCoinAddress = _COTCoinAddress;
    smartFundETHFactory = SmartFundETHFactoryInterface(_smartFundETHFactory);
    smartFundERC20Factory = SmartFundERC20FactoryInterface(_smartFundERC20Factory);
    cEther = _cEther;
  }

  /**
  * @dev Creates a new SmartFund
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

    // ERC20 case
    if(_fundType == uint256(FundType.USD) || _fundType == uint256(FundType.COT)){
      // Define coin address dependse of fund type
      address coinAddress = _fundType == uint256(FundType.USD)
      ? stableCoinAddress
      : COTCoinAddress;

      // Create ERC20 based fund
      smartFund = smartFundERC20Factory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager fee
        _successFee, // platform fee the same as a manager fee
        exchangePortalAddress,
        address(permittedExchanges),
        address(permittedPools),
        address(permittedStables),
        poolPortalAddress,
        coinAddress,
        cEther,
        _isRequireTradeVerification
      );
    }
    else if (_fundType == uint256(FundType.ETH)){
      // Create ETH Fund
      smartFund = smartFundETHFactory.createSmartFund(
        msg.sender,
        _name,
        _successFee, // manager fee
        _successFee, // platform fee the same as a manager fee
        exchangePortalAddress,
        address(permittedExchanges),
        address(permittedPools),
        poolPortalAddress,
        cEther,
        _isRequireTradeVerification
      );
    }
    else{
      revert("Unknown fund type");
    }

    smartFunds.push(smartFund);
    emit SmartFundAdded(smartFund, msg.sender);
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
    // Require that the new exchange portal is permitted by permittedExchanges
    require(permittedExchanges.permittedAddresses(_newExchangePortalAddress));

    exchangePortalAddress = _newExchangePortalAddress;
  }

  /**
  * @dev Owner can set a new default Portal Portal address
  *
  * @param _poolPortalAddress    Address of the new pool portal to be set
  */
  function setPoolPortalAddress (address _poolPortalAddress) external onlyOwner {
    // Require that the new pool portal is permitted by permittedPools
    require(permittedPools.permittedAddresses(_poolPortalAddress));

    poolPortalAddress = _poolPortalAddress;
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
    require(permittedStables.permittedAddresses(_stableCoinAddress));
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
  * @dev Allows platform to withdraw tokens received as part of the platform fee
  *
  * @param _tokenAddress    Address of the token to be withdrawn
  */
  function withdrawTokens(address _tokenAddress) external onlyOwner {
    IERC20 token = IERC20(_tokenAddress);

    token.transfer(owner(), token.balanceOf(address(this)));
  }

  /**
  * @dev Allows platform to withdraw ether received as part of the platform fee
  */
  function withdrawEther() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  // Fallback payable function in order to receive ether when fund manager withdraws their cut
  fallback() external payable {}

}
