pragma solidity ^0.6.12;

import "./SmartFundCore.sol";

/*
  Note: this smart fund inherits SmartFundCore and make core operations like deposit,
  calculate fund value etc in ETH
*/
contract SmartFundETH is SmartFundCore {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /**
  * @dev constructor
  *
  * @param _owner                        Address of the fund manager
  * @param _name                         Name of the fund, required for DetailedERC20 compliance
  * @param _successFee                   Percentage of profit that the fund manager receives
  * @param _platformAddress              Address of platform to send fees to
  * @param _exchangePortalAddress        Address of initial exchange portal
  * @param _poolPortalAddress            Address of initial pool portal
  * @param _defiPortal                   Address of defi portal
  * @param _permittedAddresses           Address of permittedAddresses contract
  * @param _isRequireTradeVerification   If true fund will require verification from Merkle White list for each new asset
  */
  constructor(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _poolPortalAddress,
    address _defiPortal,
    address _permittedAddresses,
    bool    _isRequireTradeVerification
  )
  SmartFundCore(
    _owner,
    _name,
    _successFee,
    _platformAddress,
    _exchangePortalAddress,
    _poolPortalAddress,
    _defiPortal,
    _permittedAddresses,
    address(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee),
    _isRequireTradeVerification
  )
  public{}

  /**
  * @dev Deposits ether into the fund and allocates a number of shares to the sender
  * depending on the current number of shares, the funds value, and amount deposited
  *
  * @return The amount of shares allocated to the depositor
  */
  function deposit() external payable returns (uint256) {
    // Check if the sender is allowed to deposit into the fund
    if (onlyWhitelist)
      require(whitelist[msg.sender]);

    // Require that the amount sent is not 0
    require(msg.value != 0, "ZERO_DEPOSIT");

    totalWeiDeposited += msg.value;

    // Calculate number of shares
    uint256 shares = calculateDepositToShares(msg.value);

    // If user would receive 0 shares, don't continue with deposit
    require(shares != 0, "ZERO_SHARES");

    // Add shares to total
    totalShares = totalShares.add(shares);

    // Add shares to address
    addressToShares[msg.sender] = addressToShares[msg.sender].add(shares);

    addressesNetDeposit[msg.sender] += int256(msg.value);

    emit Deposit(msg.sender, msg.value, shares, totalShares);

    return shares;
  }

  /**
  * @dev Calculates the funds value in deposit token (Ether)
  *
  * @return The current total fund value
  */
  function calculateFundValue() public override view returns (uint256) {
    uint256 ethBalance = address(this).balance;

    // If the fund only contains ether, return the funds ether balance
    if (tokenAddresses.length == 1)
      return ethBalance;

    // Otherwise, we get the value of all the other tokens in ether via exchangePortal

    // Calculate value for ERC20
    address[] memory fromAddresses = new address[](tokenAddresses.length - 1); // Sub ETH
    uint256[] memory amounts = new uint256[](tokenAddresses.length - 1);
    uint index = 0;

    for (uint256 i = 1; i < tokenAddresses.length; i++) {
      fromAddresses[index] = tokenAddresses[i];
      amounts[index] = IERC20(tokenAddresses[i]).balanceOf(address(this));
      index++;
    }
    // Ask the Exchange Portal for the value of all the funds tokens in eth
    uint256 tokensValue = exchangePortal.getTotalValue(
      fromAddresses,
      amounts,
      address(ETH_TOKEN_ADDRESS)
    );

    // Sum ETH + ERC20
    return ethBalance + tokensValue;
  }

  /**
  * @dev get balance of input asset address in ETH ratio
  *
  * @param _token     token address
  *
  * @return balance in ETH
  */
  function getTokenValue(IERC20 _token) public override view returns (uint256) {
    // return ETH
    if (_token == ETH_TOKEN_ADDRESS){
      return address(this).balance;
    }
    // return ERC20 in ETH
    else{
      uint256 tokenBalance = _token.balanceOf(address(this));
      return exchangePortal.getValue(
        address(_token),
        address(ETH_TOKEN_ADDRESS),
        tokenBalance
      );
    }
  }
}
