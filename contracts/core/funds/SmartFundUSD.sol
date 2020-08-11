pragma solidity ^0.6.12;

import "./SmartFundCore.sol";
import "../interfaces/PermittedStablesInterface.sol";


/*
  Note: this smart fund smart fund inherits SmartFundCore and make core operations like deposit,
  calculate fund value etc in USD
*/
contract SmartFundUSD is SmartFundCore {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Address of stable coin can be set in constructor and changed via function
  address public stableCoinAddress;

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
  * @param _stableCoinAddress            address of stable coin
  * @param _convertPortalAddress         Address of the convert portal
  * @param _cEther                       Address of the cEther
  * @param _permittedConvertsAddress     Address of the permitted Converts portal
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
    address _stableCoinAddress,
    address _convertPortalAddress,
    address _cEther,
    address _permittedConvertsAddress
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
    _convertPortalAddress,
    _cEther,
    _stableCoinAddress,
    _permittedConvertsAddress
  )
  public {
    // Initial stable coint interface
    permittedStables = PermittedStablesInterface(_permittedStables);
    // Initial stable coin address
    stableCoinAddress = _stableCoinAddress;
    // Push stable coin in tokens list
    _addToken(_stableCoinAddress);
  }

  /**
  * @dev Deposits stable soin into the fund and allocates a number of shares to the sender
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

    // Transfer stable coin from sender
    require(IERC20(stableCoinAddress).transferFrom(msg.sender, address(this), depositAmount),
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
  * @dev Calculates the funds value in deposit token (USD)
  *
  * @return The current total fund value
  */
  function calculateFundValue() public override view returns (uint256) {
    // Convert ETH balance to USD
    uint256 ethBalance = exchangePortal.getValue(
      address(ETH_TOKEN_ADDRESS),
      stableCoinAddress,
      address(this).balance
    );

    // If the fund only contains ether, return the funds ether balance converted in USD
    if (tokenAddresses.length == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddresses.length - 2); // sub ETH + curernt USD
    uint256[] memory amounts = new uint256[](tokenAddresses.length - 2);
    uint8 index = 0;

    // get all ERC20 addresses and balance
    for (uint8 i = 2; i < tokenAddresses.length; i++) {
      fromAddresses[index] = tokenAddresses[i];
      amounts[index] = IERC20(tokenAddresses[i]).balanceOf(address(this));
      index++;
    }
    // Ask the Exchange Portal for the value of all the funds tokens in stable coin
    uint256 tokensValue = exchangePortal.getTotalValue(fromAddresses, amounts, stableCoinAddress);

    // Get curernt USD token balance
    uint256 currentUSD = IERC20(stableCoinAddress).balanceOf(address(this));

    // Sum ETH in USD + Current USD Token + ERC20 in USD
    return ethBalance + currentUSD + tokensValue;
  }


  /**
  * @dev get balance of input asset address in USD ratio
  *
  * @param _token     token address
  *
  * @return balance in usd
  */
  function getTokenValue(IERC20 _token) public override view returns (uint256) {
    // get ETH in USD
    if (_token == ETH_TOKEN_ADDRESS){
      return exchangePortal.getValue(
        address(_token),
        stableCoinAddress,
        address(this).balance);
    }
    // get current USD
    else if(_token == IERC20(stableCoinAddress)){
      return _token.balanceOf(address(this));
    }
    // get ERC20 in USD
    else{
      uint256 tokenBalance = _token.balanceOf(address(this));
      return exchangePortal.getValue(
        address(_token),
        stableCoinAddress,
        tokenBalance
      );
    }
  }

  /**
  * @dev Sets new stableCoinAddress
  *
  * @param _stableCoinAddress    New stable address
  */
  function changeStableCoinAddress(address _stableCoinAddress) external onlyOwner {
    require(totalWeiDeposited == 0, "not allow change stable coin, if deposit is already made");
    require(permittedStables.permittedAddresses(_stableCoinAddress), "address not permitted");
    stableCoinAddress = _stableCoinAddress;
  }
}
