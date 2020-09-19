pragma solidity ^0.6.12;

/*
  The SmartFund contract is what holds all the tokens and ether, and contains all the logic
  for calculating its value (and ergo profit), allows users to deposit/withdraw their funds,
  and calculates the fund managers cut of the funds profit among other things.
  The SmartFund gets the value of its token holdings (in Ether) and trades through the ExchangePortal
  contract. This means that as new exchange capabalities are added to new exchange portals, the
  SmartFund will be able to upgrade to a new exchange portal, and trade a wider variety of assets
  with a wider variety of exchanges. The SmartFund is also connected to a permittedAddresses contract,
  which determines which exchange, pool, defi portals the SmartFund is allowed to connect to, restricting
  the fund owners ability to connect to a potentially malicious contract.

  In additional this contract can use pools and defi protocols voa pool and defi portals.
*/


import "../interfaces/ExchangePortalInterface.sol";
import "../interfaces/PoolPortalInterface.sol";
import "../interfaces/DefiPortalInterface.sol";
import "../interfaces/PermittedAddressesInterface.sol";

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/access/Ownable.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../zeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

abstract contract SmartFundCore is Ownable, IERC20 {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Fund type
  bool public isLightFund = false;

  // Total amount of ether or stable deposited by all users
  uint256 public totalWeiDeposited = 0;

  // Total amount of ether or stable withdrawn by all users
  uint256 public totalWeiWithdrawn = 0;

  // The Interface of the Exchange Portal
  ExchangePortalInterface public exchangePortal;

  // The Interface of pool portall
  PoolPortalInterface public poolPortal;

  // The interface of DefiPortal
  DefiPortalInterface public defiPortal;

  // The Smart Contract which stores the addresses of all the authorized Exchange Portals
  PermittedAddressesInterface public permittedAddresses;

  // portals recognizes ETH by this address
  IERC20 constant internal ETH_TOKEN_ADDRESS = IERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

  // For ERC20 compliance
  string public name;

  // The maximum amount of tokens that can be traded via the smart fund
  uint256 public MAX_TOKENS = 20;

  // Percentages are rounded to 3 decimal places
  uint256 public TOTAL_PERCENTAGE = 10000;

  // Address of the platform that takes a cut from the fund manager success cut
  address public platformAddress;

  // The percentage of earnings paid to the fund manager. 10000 = 100%
  // e.g. 10% is 1000
  uint256 public successFee;

  // The percentage of fund manager earnings paid to the platform. 10000 = 100%
  // e.g. 10% is 1000
  uint256 public platformFee;

  // An array of all the erc20 token addresses the smart fund holds
  address[] public tokenAddresses;

  // Boolean value that determines whether the fund accepts deposits from anyone or
  // only specific addresses approved by the manager
  bool public onlyWhitelist = false;

  // Mapping of addresses that are approved to deposit if the manager only want's specific
  // addresses to be able to invest in their fund
  mapping (address => bool) public whitelist;

  uint public version = 7;

  // the total number of shares in the fund
  uint256 public totalShares = 0;

  // Denomination of initial shares
  uint256 constant internal INITIAL_SHARES = 10 ** 18;

  // The earnings the fund manager has already cashed out
  uint256 public fundManagerCashedOut = 0;

  // for ETH and USD fund this asset different
  address public coreFundAsset;

  // If true the contract will require each new asset to buy to be on a special Merkle tree list
  bool public isRequireTradeVerification;

  // how many shares belong to each address
  mapping (address => uint256) public addressToShares;

  // so that we can easily check that we don't add duplicates to our array
  mapping (address => bool) public tokensTraded;

  // this is really only being used to more easily show profits, but may not be necessary
  // if we do a lot of this offchain using events to track everything
  // total `depositToken` deposited - total `depositToken` withdrawn
  mapping (address => int256) public addressesNetDeposit;

  // Events
  event DefiCall(
    string eventType,
    address[] tokensToSend,
    uint256[] amountsToSend,
    address[] tokensToReceive,
    uint256[] amountsToReceive
    );

  event BuyPool(
    address poolAddress,
    uint256 poolAmount,
    address[] connectorsAddress,
    uint256[] connectorsAmount);

  event SellPool(
    address poolAddress,
    uint256 poolAmount,
    address[] connectorsAddress,
    uint256[] connectorsAmount);

  event Deposit(address indexed user, uint256 amount, uint256 sharesReceived, uint256 totalShares);
  event Withdraw(address indexed user, uint256 sharesRemoved, uint256 totalShares);
  event Trade(address src, uint256 srcAmount, address dest, uint256 destReceived);
  event SmartFundCreated(address indexed owner);


  constructor(
    address _owner,
    string memory _name,
    uint256 _successFee,
    address _platformAddress,
    address _exchangePortalAddress,
    address _poolPortalAddress,
    address _defiPortal,
    address _permittedAddresses,
    address _coreFundAsset,
    bool    _isRequireTradeVerification
  )public{
    // never allow a 100% fee
    require(_successFee < TOTAL_PERCENTAGE);

    name = _name;
    successFee = _successFee;
    platformFee = _successFee; // platform fee the same as manager fee 

    // Init manager
    if(_owner == address(0)){
      transferOwnership(msg.sender);
    }
    else{
      transferOwnership(_owner);
    }

    // Init platform address
    if(_platformAddress == address(0)){
      platformAddress = msg.sender;
    }
    else{
      platformAddress = _platformAddress;
    }

    // Initial Token is Ether
    tokenAddresses.push(address(ETH_TOKEN_ADDRESS));

    // Initial interfaces
    exchangePortal = ExchangePortalInterface(_exchangePortalAddress);
    poolPortal = PoolPortalInterface(_poolPortalAddress);
    defiPortal = DefiPortalInterface(_defiPortal);
    permittedAddresses = PermittedAddressesInterface(_permittedAddresses);

    // Initial core assets
    coreFundAsset = _coreFundAsset;

    // Initial check if fund require trade verification or not
    isRequireTradeVerification = _isRequireTradeVerification;

    emit SmartFundCreated(owner());
  }

  // virtual methods
  // USD and ETH based funds have different implements of this methods
  function calculateFundValue() public virtual view returns (uint256);
  function getTokenValue(IERC20 _token) public virtual view returns (uint256);


  /**
  * @dev Sends (_mul/_div) of every token (and ether) the funds holds to _withdrawAddress
  *
  * @param _mul                The numerator
  * @param _div                The denominator
  * @param _withdrawAddress    Address to send the tokens/ether to
  *
  * NOTE: _withdrawAddress changed from address to address[] arrays because balance calculation should be performed
  * once for all usesr who wants to withdraw from the current balance.
  *
  */
  function _withdraw(
    uint256[] memory _mul,
    uint256[] memory _div,
    address[] memory _withdrawAddress
    )
    internal
    returns (uint256)
  {
    for (uint8 i = 1; i < tokenAddresses.length; i++) {
      // Transfer that _mul/_div of each token we hold to the user
      IERC20 token = IERC20(tokenAddresses[i]);
      uint256 fundAmount = token.balanceOf(address(this));

      // Transfer ERC20 to _withdrawAddress
      for(uint8 j = 0; j < _withdrawAddress.length; j++){
        // calculate withdraw ERC20 share
        uint256 payoutAmount = fundAmount.mul(_mul[j]).div(_div[j]);
        if(payoutAmount > 0)
          token.transfer(_withdrawAddress[j], payoutAmount);
      }
    }
    // Transfer ETH to _withdrawAddress
    uint256 etherBalance = address(this).balance;
    for(uint8 k = 0; k < _withdrawAddress.length; k++){
      // calculate withdraw ETH share
      uint256 etherPayoutAmount = (etherBalance).mul(_mul[k]).div(_div[k]);
      if(etherPayoutAmount > 0)
        payable(_withdrawAddress[k]).transfer(etherPayoutAmount);
    }
  }

  /**
  * @dev Withdraws users fund holdings, sends (userShares/totalShares) of every held token
  * to msg.sender, defaults to 100% of users shares.
  *
  * @param _percentageWithdraw    The percentage of the users shares to withdraw.
  */
  function withdraw(uint256 _percentageWithdraw) external {
    require(totalShares != 0, "EMPTY_SHARES");
    require(_percentageWithdraw <= TOTAL_PERCENTAGE, "INCORRECT_PERCENT");

    uint256 percentageWithdraw = (_percentageWithdraw == 0) ? TOTAL_PERCENTAGE : _percentageWithdraw;

    uint256 addressShares = addressToShares[msg.sender];

    uint256 numberOfWithdrawShares = addressShares.mul(percentageWithdraw).div(TOTAL_PERCENTAGE);

    uint256 fundManagerCut;
    uint256 fundValue;

    // Withdraw the users share minus the fund manager's success fee
    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 withdrawShares = numberOfWithdrawShares.mul(fundValue.sub(fundManagerCut)).div(fundValue);

    // prepare call data for _withdarw
    address[] memory spenders = new address[](1);
    spenders[0] = msg.sender;

    uint256[] memory value = new uint256[](1);
    value[0] = totalShares;

    uint256[] memory cut = new uint256[](1);
    cut[0] = withdrawShares;

    // do withdraw
    _withdraw(cut, value, spenders);

    // Store the value we are withdrawing in ether
    uint256 valueWithdrawn = fundValue.mul(withdrawShares).div(totalShares);

    totalWeiWithdrawn = totalWeiWithdrawn.add(valueWithdrawn);
    addressesNetDeposit[msg.sender] -= int256(valueWithdrawn);

    // Subtract from total shares the number of withdrawn shares
    totalShares = totalShares.sub(numberOfWithdrawShares);
    addressToShares[msg.sender] = addressToShares[msg.sender].sub(numberOfWithdrawShares);

    emit Withdraw(msg.sender, numberOfWithdrawShares, totalShares);
  }

  /**
  * @dev Facilitates a trade of the funds holdings via the exchange portal
  *
  * @param _source            ERC20 token to convert from
  * @param _sourceAmount      Amount to convert (in _source token)
  * @param _destination       ERC20 token to convert to
  * @param _type              The type of exchange to trade with
  * @param _proof             Merkle tree proof (if not used just set [])
  * @param _positions         Merkle tree positions (if not used just set [])
  * @param _additionalData    For additional data (if not used just set "0x0")
  * @param _minReturn         Min expected amount of destination
  */
  function trade(
    IERC20 _source,
    uint256 _sourceAmount,
    IERC20 _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    uint256 _minReturn
  ) external onlyOwner {
    require(_minReturn > 0, "MIN_RETURN_0");

    uint256 receivedAmount;

    if (_source == ETH_TOKEN_ADDRESS) {
      // Make sure fund contains enough ether
      require(address(this).balance >= _sourceAmount, "NOT_ENOUGH_ETH");
      // Call trade on ExchangePortal along with ether
      receivedAmount = exchangePortal.trade.value(_sourceAmount)(
        _source,
        _sourceAmount,
        _destination,
        _type,
        _proof,
        _positions,
        _additionalData,
        isRequireTradeVerification
      );
    } else {
      _source.approve(address(exchangePortal), _sourceAmount);
      receivedAmount = exchangePortal.trade(
        _source,
        _sourceAmount,
        _destination,
        _type,
        _proof,
        _positions,
        _additionalData,
        isRequireTradeVerification
      );
    }

    // make sure fund recive destanation
    require(receivedAmount >= _minReturn, "RECEIVED_LESS_THAN_MIN_RETURN");

    // add token to trader list
    _addToken(address(_destination));

    // emit event
    emit Trade(
      address(_source),
      _sourceAmount,
      address(_destination),
      receivedAmount);
  }


  /**
  * @dev buy pool via pool portal
  *
  * @param _amount             For Bancor amount it's relay, for Uniswap amount it's ETH, for Bancor and Uniswap v2 can be 0
  * @param _type               type of pool (0 - Bancor, 1 - Uniswap)
  * @param _poolToken          address of relay for Bancor and exchange for Uniswap
  * @param _connectorsAddress  address of pool connectors
  * @param _connectorsAmount   amount of pool connectors
  * @param _additionalArgs     bytes32 array for case if need pass some extra params, can be empty
  * @param _additionData       for provide any additional data, if not used just set "0x"
  */
  function buyPool(
   uint256            _amount,
   uint               _type,
   address            _poolToken,
   address[] calldata _connectorsAddress,
   uint256[] memory   _connectorsAmount,  // WARNING: this array rewrite from buyPool return (details below)
   bytes32[] calldata _additionalArgs,
   bytes calldata     _additionData
  )
  external onlyOwner {
   // for determine the exact number of received pool
   uint256 poolAmountReceive;

   // approve connectors
   // etherAmount for detect ETH case
   uint256 etherAmount = approveArrayOfTokensToSpender(
     _connectorsAddress,
     _connectorsAmount,
     address(poolPortal)
   );

   // buy pool with ETH (payable case)
   if(etherAmount > 0){
     // WARNING: rewrire _connectorsAmount from return
     // some pools can return some remains for connectors, and for get correct result,
     // for connectors amount to spend for emit event
     // poolPortal calculates and return exactly how many tokens were spent (total - remains),
     // unfortunate due stack too deep issue, we can't declarate new variable
     // so we rewrire _connectorsAmount
    (poolAmountReceive, _connectorsAmount) = poolPortal.buyPool.value(etherAmount)(
      _amount,
      _type,
     _poolToken,
     _connectorsAddress,
     _connectorsAmount,
     _additionalArgs,
     _additionData
     );
   }
   // buy pool only with ERC20 (non payable case)
   else{
     // WARNING: rewrire _connectorsAmount from return
     (poolAmountReceive, _connectorsAmount) = poolPortal.buyPool(
      _amount,
      _type,
     _poolToken,
     _connectorsAddress,
     _connectorsAmount,
     _additionalArgs,
     _additionData
     );
   }
   // make sure fund receive pool token
   require(poolAmountReceive > 0, "EMPTY_POOL_RETURN");
   // Add pool as ERC20 for withdraw
   _addToken(_poolToken);
   // emit event
   emit BuyPool(
     _poolToken,
     poolAmountReceive,
     _connectorsAddress,
     _connectorsAmount);
  }


  /**
  * @dev sell pool via pool portal
  *
  * @param _amount          amount of Bancor relay or Uniswap exchange to sell
  * @param _type            type of pool (0 - Bancor, 1 - Uniswap)
  * @param _poolToken       address of Bancor relay or Uniswap exchange
  * @param _additionalArgs  bytes32 array for case if need pass some extra params, can be empty
  * @param _additionData    for provide any additional data, if not used just set "0x"
  */
  function sellPool(
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionData
  )
  external onlyOwner {
    // approve pool
    _poolToken.approve(address(poolPortal), _amount);

    // sell pool
    (address[] memory connectorsAddress,
     uint256[] memory connectorsAmount) = poolPortal.sellPool(
      _amount,
      _type,
     _poolToken,
     _additionalArgs,
     _additionData
    );

    // Add connectors to fund
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      _addToken(connectorsAddress[i]);
    }

    // event
    emit SellPool(
      address(_poolToken),
      _amount,
      connectorsAddress,
      connectorsAmount);
  }

  /**
  * @dev allow manager use newest DEFI protocols
  * NOTE: all logic in DEFI portal hardcoded, and also fund manager can't update
  * non permitted DEFI portal, so this is safe call
  *

  * @param _additionalData               params data packed in bytes
  * @param _additionalArgs      additional params array for quick unpack

  */
  function callDefiPortal(
    address[] memory tokensToSend,
    uint256[] memory amountsToSend,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
    external
    onlyOwner
  {
    // event data
    string memory eventType;
    address[] memory tokensToReceive;
    uint256[] memory amountsToReceive;

    // approve connectors
    // etherAmount for detect ETH case
    uint256 etherAmount = approveArrayOfTokensToSpender(
      tokensToSend,
      amountsToSend,
      address(defiPortal)
    );

    // call defi payable case
    if(etherAmount > 0){
      (eventType,
       tokensToReceive,
       amountsToReceive) = defiPortal.callPayableProtocol.value(etherAmount)(
         tokensToSend,
         amountsToSend,
         _additionalData,
         _additionalArgs
        );
    }
    // call defi not payable case
    else{
      (eventType,
       tokensToReceive,
       amountsToReceive) = defiPortal.callNonPayableProtocol(
         tokensToSend,
         amountsToSend,
         _additionalData,
         _additionalArgs
        );
    }

   // add new tokens in fund
   for(uint8 i = 0; i < tokensToReceive.length; i++){
     _addToken(tokensToReceive[i]);
   }

   // emit event
    emit DefiCall(
      eventType,
      tokensToSend,
      amountsToSend,
      tokensToReceive,
      amountsToReceive
    );
  }


  // pivate helper for approve arary of tokens
  // spender can be Pool or Defi portals
  function approveArrayOfTokensToSpender(
    address[] memory addresses,
    uint256[] memory amounts,
    address spender
  )
    private
    returns (uint256 etherAmount)
  {
    for(uint8 i = 0; i < addresses.length; i++){
      if(addresses[i] != address(ETH_TOKEN_ADDRESS)){
        // approve
        IERC20(addresses[i]).approve(spender, amounts[i]);
      }
      else{
        etherAmount = amounts[i];
      }
    }
  }


  // return all tokens addresses from fund
  function getAllTokenAddresses() external view returns (address[] memory) {
    return tokenAddresses;
  }

  /**
  * @dev Adds a token to tokensTraded if it's not already there
  * @param _token    The token to add
  */
  function _addToken(address _token) internal {
    // don't add token to if we already have it in our list
    if (tokensTraded[_token] || (_token == address(ETH_TOKEN_ADDRESS)))
      return;

    tokensTraded[_token] = true;
    tokenAddresses.push(_token);
    uint256 tokenCount = tokenAddresses.length;

    // we can't hold more than MAX_TOKENS tokens
    require(tokenCount <= MAX_TOKENS, "MAX_TOKENS");
  }

  /**
  * @dev Removes a token from tokensTraded
  *
  * @param _token         The address of the token to be removed
  * @param _tokenIndex    The index of the token to be removed
  *
  */
  function removeToken(address _token, uint256 _tokenIndex) public onlyOwner {
    require(_token != address(ETH_TOKEN_ADDRESS));
    require(tokensTraded[_token]);
    require(IERC20(_token).balanceOf(address(this)) == 0);
    require(tokenAddresses[_tokenIndex] == _token);

    tokensTraded[_token] = false;

    // remove token from array
    uint256 arrayLength = tokenAddresses.length - 1;
    tokenAddresses[_tokenIndex] = tokenAddresses[arrayLength];
    delete tokenAddresses[arrayLength];
    tokenAddresses.pop();
  }

  /**
  * @dev Calculates the funds profit
  *
  * @return The funds profit in deposit token (Ether)
  */
  function calculateFundProfit() public view returns (int256) {
    uint256 fundValue = calculateFundValue();

    return int256(fundValue) + int256(totalWeiWithdrawn) - int256(totalWeiDeposited);
  }

  /**
  * @dev Calculates the amount of shares received according to ether deposited
  *
  * @param _amount    Amount of ether to convert to shares
  *
  * @return Amount of shares to be received
  */
  function calculateDepositToShares(uint256 _amount) public view returns (uint256) {
    uint256 fundManagerCut;
    uint256 fundValue;

    // If there are no shares in the contract, whoever deposits owns 100% of the fund
    // we will set this to 10^18 shares, but this could be any amount
    if (totalShares == 0)
      return INITIAL_SHARES;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 fundValueBeforeDeposit = fundValue.sub(_amount).sub(fundManagerCut);

    if (fundValueBeforeDeposit == 0)
      return 0;

    return _amount.mul(totalShares).div(fundValueBeforeDeposit);

  }


  /**
  * @dev Calculates the fund managers cut, depending on the funds profit and success fee
  *
  * @return fundManagerRemainingCut    The fund managers cut that they have left to withdraw
  * @return fundValue                  The funds current value
  * @return fundManagerTotalCut        The fund managers total cut of the profits until now
  */
  function calculateFundManagerCut() public view returns (
    uint256 fundManagerRemainingCut, // fm's cut of the profits that has yet to be cashed out (in `depositToken`)
    uint256 fundValue, // total value of fund (in `depositToken`)
    uint256 fundManagerTotalCut // fm's total cut of the profits (in `depositToken`)
  ) {
    fundValue = calculateFundValue();
    // The total amount of ether currently deposited into the fund, takes into account the total ether
    // withdrawn by investors as well as ether withdrawn by the fund manager
    // NOTE: value can be negative if the manager performs well and investors withdraw more
    // ether than they deposited
    int256 curtotalWeiDeposited = int256(totalWeiDeposited) - int256(totalWeiWithdrawn.add(fundManagerCashedOut));

    // If profit < 0, the fund managers totalCut and remainingCut are 0
    if (int256(fundValue) <= curtotalWeiDeposited) {
      fundManagerTotalCut = 0;
      fundManagerRemainingCut = 0;
    } else {
      // calculate profit. profit = current fund value - total deposited + total withdrawn + total withdrawn by fm
      uint256 profit = uint256(int256(fundValue) - curtotalWeiDeposited);
      // remove the money already taken by the fund manager and take percentage
      fundManagerTotalCut = profit.mul(successFee).div(TOTAL_PERCENTAGE);
      fundManagerRemainingCut = fundManagerTotalCut.sub(fundManagerCashedOut);
    }
  }

  /**
  * @dev Allows the fund manager to withdraw their cut of the funds profit
  */
  function fundManagerWithdraw() public onlyOwner {
    uint256 fundManagerCut;
    uint256 fundValue;

    (fundManagerCut, fundValue, ) = calculateFundManagerCut();

    uint256 platformCut = (platformFee == 0) ? 0 : fundManagerCut.mul(platformFee).div(TOTAL_PERCENTAGE);

    // prepare call data for _withdarw
    address[] memory spenders = new address[](2);
    spenders[0] = platformAddress;
    spenders[1] = owner();

    uint256[] memory value = new uint256[](2);
    value[0] = fundValue;
    value[1] = fundValue;

    uint256[] memory cut = new uint256[](2);
    cut[0] = platformCut;
    cut[1] = fundManagerCut - platformCut;

    // do withdraw
    _withdraw(cut, value, spenders);

    // add report
    fundManagerCashedOut = fundManagerCashedOut.add(fundManagerCut);
  }

  // calculate the current value of an address's shares in the fund
  function calculateAddressValue(address _address) public view returns (uint256) {
    if (totalShares == 0)
      return 0;

    return calculateFundValue().mul(addressToShares[_address]).div(totalShares);
  }

  // calculate the net profit/loss for an address in this fund
  function calculateAddressProfit(address _address) public view returns (int256) {
    uint256 currentAddressValue = calculateAddressValue(_address);

    return int256(currentAddressValue) - addressesNetDeposit[_address];
  }

  // This method was added to easily record the funds token balances, may (should?) be removed in the future
  function getFundTokenHolding(IERC20 _token) external view returns (uint256) {
    if (_token == ETH_TOKEN_ADDRESS)
      return address(this).balance;
    return _token.balanceOf(address(this));
  }

  /**
  * @dev Allows the manager to set whether or not only whitelisted addresses can deposit into
  * their fund
  *
  * @param _onlyWhitelist    boolean representing whether only whitelisted addresses can deposit
  */
  function setWhitelistOnly(bool _onlyWhitelist) external onlyOwner {
    onlyWhitelist = _onlyWhitelist;
  }

  /**
  * @dev Allows the fund manager to whitelist specific addresses to control
  * whos allowed to deposit into the fund
  *
  * @param _user       The user address to whitelist
  * @param _allowed    The status of _user, true means allowed to deposit, false means not allowed
  */
  function setWhitelistAddress(address _user, bool _allowed) external onlyOwner {
    whitelist[_user] = _allowed;
  }

  /**
  * @dev Allows the fund manager to connect to a new permitted exchange portal
  *
  * @param _newExchangePortalAddress    The address of the new permitted exchange portal to use
  */
  function setNewExchangePortal(address _newExchangePortalAddress) public onlyOwner {
    // Require correct permitted address type
    require(permittedAddresses.isMatchTypes(_newExchangePortalAddress, 1), "WRONG_ADDRESS");
    // Set new
    exchangePortal = ExchangePortalInterface(_newExchangePortalAddress);
  }

  /**
  * @dev Allows the fund manager to connect to a new permitted poolPortal
  *
  * @param _newPoolPortal   The address of the new permitted pool portal to use
  */
  function setNewPoolPortal(address _newPoolPortal) public onlyOwner {
    // Require correct permitted address type
    require(permittedAddresses.isMatchTypes(_newPoolPortal, 2), "WRONG_ADDRESS");
    // Set new
    poolPortal = PoolPortalInterface(_newPoolPortal);
  }


  /**
  * @dev Allows the fund manager to connect to a new permitted defi portal
  *
  * @param _newDefiPortalAddress    The address of the new permitted defi portal to use
  */
  function setNewDefiPortal(address _newDefiPortalAddress) public onlyOwner {
    // Require correct permitted address type
    require(permittedAddresses.isMatchTypes(_newDefiPortalAddress, 3), "WRONG_ADDRESS");
    // Set new
    defiPortal = DefiPortalInterface(_newDefiPortalAddress);
  }

  /**
  * @dev This method is present in the alpha testing phase in case for some reason there are funds
  * left in the SmartFund after all shares were withdrawn
  *
  * @param _token    The address of the token to withdraw
  */
  function emergencyWithdraw(address _token) external onlyOwner {
    require(totalShares == 0);
    if (_token == address(ETH_TOKEN_ADDRESS)) {
      msg.sender.transfer(address(this).balance);
    } else {
      IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
  }

  /**
  * @dev Approve 0 for a certain address
  *
  * NOTE: Some ERC20 has no standard approve logic, and not allow do new approve
  * if alredy approved.
  *
  * @param _token                   address of ERC20
  * @param _spender                 address of spender
  */
  function resetApprove(address _token, address _spender) external onlyOwner {
    IERC20(_token).approve(_spender, 0);
  }

  // Fallback payable function in order to be able to receive ether from other contracts
  fallback() external payable {}

  /**
    **************************** ERC20 Compliance ****************************
  **/

  // Note that addressesNetDeposit does not get updated when transferring shares, since
  // this is used for updating off-chain data it doesn't affect the smart contract logic,
  // but is an issue that currently exists

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  uint8 public decimals = 18;

  string public symbol = "FND";

  mapping (address => mapping (address => uint256)) internal allowed;

  /**
  * @dev Total number of shares in existence
  */
  function totalSupply() external override view returns (uint256) {
    return totalShares;
  }

  /**
  * @dev Gets the balance of the specified address.
  *
  * @param _who    The address to query the the balance of.
  *
  * @return A uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _who) external override view returns (uint256) {
    return addressToShares[_who];
  }

  /**
  * @dev Transfer shares for a specified address
  *
  * @param _to       The address to transfer to.
  * @param _value    The amount to be transferred.
  *
  * @return true upon success
  */
  function transfer(address _to, uint256 _value) external override returns (bool) {
    require(_to != address(0));
    require(_value <= addressToShares[msg.sender]);

    addressToShares[msg.sender] = addressToShares[msg.sender].sub(_value);
    addressToShares[_to] = addressToShares[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * @dev Transfer shares from one address to another
   *
   * @param _from     The address which you want to send tokens from
   * @param _to       The address which you want to transfer to
   * @param _value    The amount of shares to be transferred
   *
   * @return true upon success
   */
  function transferFrom(address _from, address _to, uint256 _value) external override returns (bool) {
    require(_to != address(0));
    require(_value <= addressToShares[_from]);
    require(_value <= allowed[_from][msg.sender]);

    addressToShares[_from] = addressToShares[_from].sub(_value);
    addressToShares[_to] = addressToShares[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of shares on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * @param _spender    The address which will spend the funds.
   * @param _value      The amount of shares to be spent.
   *
   * @return true upon success
   */
  function approve(address _spender, uint256 _value) external override returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of shares that an owner allowed to a spender.
   *
   * @param _owner      The address which owns the funds.
   * @param _spender    The address which will spend the funds.
   *
   * @return A uint256 specifying the amount of shares still available for the spender.
   */
  function allowance(address _owner, address _spender) external override view returns (uint256) {
    return allowed[_owner][_spender];
  }
}
