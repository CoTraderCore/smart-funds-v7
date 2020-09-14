pragma solidity ^0.6.12;

import "./SmartFundCore.sol";
import "../interfaces/PermittedStablesInterface.sol";


/*
  Note: this smart fund smart fund inherits SmartFundCore and make core operations like deposit,
  calculate fund value etc in ERC20
*/
contract SmartFundERC20 is SmartFundCore {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Address of core coin can be set in constructor and for USD coins case can be changed via function
  address public coinAddress;

  // State for recognize if this fund stable asset based
  bool public isStableCoinBasedFund;

  // The Smart Contract which stores the addresses of all the authorized stable coins
  PermittedStablesInterface public permittedStables;

  /**
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  * @param _name                         Name of the fund, required for DetailedERC20 compliance
  * @param _successFee                   Percentage of profit that the fund manager receives
  * @param _platformFee                  Percentage of the success fee that goes to the platform
  * @param _platformAddress              Address of platform to send fees to
  * @param _exchangePortalAddress        Address of initial exchange portal
  * @param _permittedExchangesAddress    Address of PermittedExchanges contract
  * @param _permittedPoolsAddress        Address of PermittedPools contract
  * @param _permittedStables             Address of permittedStables contract
  * @param _poolPortalAddress            Address of initial pool portal
  * @param _coinAddress                  Address of core ERC20 coin

  * @param _isRequireTradeVerification   If true fund will require verification from Merkle White list for each new asset
  */
  constructor(
    address _owner,
    string memory _name,
    uint256 _successFee,
    uint256 _platformFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _permittedExchangesAddress,
    address _permittedPoolsAddress,
    address _permittedStables,
    address _poolPortalAddress,
    address _defiPortal,
    address _permittedDefiPortalAddress,
    address _coinAddress,
    bool    _isRequireTradeVerification
  )
  SmartFundCore(
    _owner,
    _name,
    _successFee,
    _platformFee,
    _platformAddress,
    _exchangePortalAddress,
    _permittedExchangesAddress,
    _permittedPoolsAddress,
    _poolPortalAddress,
    _defiPortal,
    _permittedDefiPortalAddress,
    _coinAddress,
    _isRequireTradeVerification
  )
  public {
    // Initial stable coint permitted interface
    permittedStables = PermittedStablesInterface(_permittedStables);
    // Initial coin address
    coinAddress = _coinAddress;
    // Push coin in tokens list
    _addToken(_coinAddress);
    // Check if this is stable coin based fund
    isStableCoinBasedFund = permittedStables.permittedAddresses(_coinAddress);
  }

  /**
  * @dev Deposits core coin into the fund and allocates a number of shares to the sender
  * depending on the current number of shares, the funds value, and amount deposited
  *
  * @return The amount of shares allocated to the depositor
  */
  function deposit(uint256 depositAmount) external returns (uint256) {
    // Check if the sender is allowed to deposit into the fund
    if (onlyWhitelist)
      require(whitelist[msg.sender]);

    // Require that the amount sent is not 0
    require(depositAmount > 0, "deposit amount should be more than zero");

    // Transfer core ERC20 coin from sender
    require(IERC20(coinAddress).transferFrom(msg.sender, address(this), depositAmount),
    "can not transfer from");

    totalWeiDeposited += depositAmount;

    // Calculate number of shares
    uint256 shares = calculateDepositToShares(depositAmount);

    // If user would receive 0 shares, don't continue with deposit
    require(shares != 0, "shares can not be zero");

    // Add shares to total
    totalShares = totalShares.add(shares);

    // Add shares to address
    addressToShares[msg.sender] = addressToShares[msg.sender].add(shares);

    addressesNetDeposit[msg.sender] += int256(depositAmount);

    emit Deposit(msg.sender, depositAmount, shares, totalShares);

    return shares;
  }


  /**
  * @dev Calculates the funds value in deposited token
  *
  * @return The current total fund value
  */
  function calculateFundValue() public override view returns (uint256) {
    // Convert ETH balance to core ERC20
    uint256 ethBalance = exchangePortal.getValue(
      address(ETH_TOKEN_ADDRESS),
      coinAddress,
      address(this).balance
    );

    // If the fund only contains ether, return the funds ether balance converted in core ERC20
    if (tokenAddresses.length == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddresses.length - 2); // sub ETH + curernt core ERC20
    uint256[] memory amounts = new uint256[](tokenAddresses.length - 2);
    uint8 index = 0;

    // get all ERC20 addresses and balance
    for (uint8 i = 2; i < tokenAddresses.length; i++) {
      fromAddresses[index] = tokenAddresses[i];
      amounts[index] = IERC20(tokenAddresses[i]).balanceOf(address(this));
      index++;
    }
    // Ask the Exchange Portal for the value of all the funds tokens in core coin
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, coinAddress);

    // Get curernt core ERC20 token balance
    uint256 currentERC20 = IERC20(coinAddress).balanceOf(address(this));

    // Sum ETH in ERC20 + Current ERC20 Token + ERC20 in ERC20
    return ethBalance + currentERC20 + tokensValue;
  }


  /**
  * @dev get balance of input asset address in current core ERC20 ratio
  *
  * @param _token     token address
  *
  * @return balance in core ERC20
  */
  function getTokenValue(IERC20 _token) public override view returns (uint256) {
    // get ETH in core ERC20
    if (_token == ETH_TOKEN_ADDRESS){
      return exchangePortal.getValue(
        address(_token),
        coinAddress,
        address(this).balance);
    }
    // get current core ERC20
    else if(_token == IERC20(coinAddress)){
      return _token.balanceOf(address(this));
    }
    // get ERC20 in core ERC20
    else{
      uint256 tokenBalance = _token.balanceOf(address(this));
      return exchangePortal.getValue(
        address(_token),
        coinAddress,
        tokenBalance
      );
    }
  }

  /**
  * @dev sets new coinAddress NOTE: this works only for stable coins
  *
  * @param _coinAddress    New stable address
  */
  function changeStableCoinAddress(address _coinAddress) external onlyOwner {
    require(isStableCoinBasedFund, "can not update non stable coin based fund");
    require(totalWeiDeposited == 0, "deposit is already made");
    require(permittedStables.permittedAddresses(_coinAddress), "address not permitted");
    coinAddress = _coinAddress;
  }
}
