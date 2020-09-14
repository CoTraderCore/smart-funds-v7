// For support new Defi protocols
pragma solidity ^0.6.12;

contract DefiPortal {
  // COMPOUND ETH wrapper address
  address public cEther;

  constructor(address _cEther) public {
    cEther = _cEther;
  }

  function callPayableProtocol(
    bytes memory _data,
    bytes32[] memory _additionalArgs
  )
    external
    payable
    returns(
      string memory eventType,
      address[] memory tokensSent,
      address[] memory tokensReceived,
      uint256[] memory amountSent,
      uint256[] memory amountReceived
    )
  {

  }

  function callNonPayableProtocol(
    bytes memory _data,
    bytes32[] memory _additionalArgs
  )
    external
    returns(
      string memory eventType
      address[] memory tokensSent
      address[] memory tokensReceived
      uint256[] memory amountSent
      uint256[] memory amountReceived,
    )
  {

  }

  /**
  * @dev buy Compound cTokens
  *
  * @param _amount       amount of ERC20 or ETH
  * @param _cToken       cToken address
  */
  function compoundMint(uint256 _amount, address _cToken) private {
    uint256 receivedAmount;
    address underlying;
    // Loan ETH
    if(_cToken == address(cEther)){
      underlying = address(ETH_TOKEN_ADDRESS);
      receivedAmount = exchangePortal.compoundMint.value(_amount)(
        _amount,
        _cToken
      );
    }
    // Loan ERC20
    else{
      underlying = exchangePortal.getCTokenUnderlying(_cToken);
      IERC20(underlying).approve(address(exchangePortal), _amount);
      receivedAmount = exchangePortal.compoundMint(
        _amount,
        _cToken
      );
    }

    _addToken(_cToken);

    // emit Loan(_cToken, receivedAmount, underlying, _amount);
  }

  /**
  * @dev sell certain percent of Ctokens to Compound
  *
  * @param _percent      percent from 1 to 100
  * @param _cToken       cToken address
  */
  function compoundRedeemByPercent(uint256 _percent, address _cToken) private {
    // get cToken amount by percent
    uint256 amount = exchangePortal.getPercentFromCTokenBalance(
      _percent,
      _cToken,
      address(this)
    );

    // get underlying address
    address underlying = (_cToken == cEther)
    ? address(ETH_TOKEN_ADDRESS)
    : exchangePortal.getCTokenUnderlying(_cToken);

    // Approve
    IERC20(_cToken).approve(address(exchangePortal), amount);

    // Redeem
    uint256 receivedAmount = exchangePortal.compoundRedeemByPercent(
      _percent,
      _cToken
    );

    // Add token
    _addToken(underlying);

    // emit event
    // emit Redeem(_cToken, amount, underlying, receivedAmount);
  }
}
