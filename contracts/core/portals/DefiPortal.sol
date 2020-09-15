// For support new Defi protocols
pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../compound/CToken.sol";
import "../../compound/CEther.sol";


contract DefiPortal {
  // COMPOUND ETH wrapper address
  CEther public cEther;

  // Enum
  // NOTE: You can add a new type at the end, but DO NOT CHANGE this order
  enum DefiActions { CompoundLoan, CompoundReedem }

  constructor(address _cEther) public {
    cEther = CEther(_cEther);
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

  // get underlying by cToken
  function getCTokenUnderlying(address _cToken)
    public
    view
    returns(address)
  {
    return CToken(_cToken).underlying();
  }

  // emit Loan(_cToken, receivedAmount, underlying, _amount);
  /**
  * @dev buy Compound cTokens
  *
  * @param _amount       amount of ERC20 or ETH
  * @param _cToken       cToken address
  */
  function compoundMint(uint256 _amount, address _cToken)
   external
   returns(uint256)
  {
    uint256 receivedAmount = 0;
    if(_cToken == address(cEther)){
      // mint cETH
      cEther.mint.value(_amount)();
      // transfer received cETH back to fund
      receivedAmount = cEther.balanceOf(address(this));
      cEther.transfer(msg.sender, receivedAmount);
    }else{
      // mint cERC20
      CToken cToken = CToken(_cToken);
      address underlyingAddress = cToken.underlying();
      _transferFromSenderAndApproveTo(IERC20(underlyingAddress), _amount, address(_cToken));
      cToken.mint(_amount);
      // transfer received cERC back to fund
      receivedAmount = cToken.balanceOf(address(this));
      cToken.transfer(msg.sender, receivedAmount);
    }

    require(receivedAmount > 0, "received amount can not be zerro");

    tokensTypes.addNewTokenType(_cToken, "COMPOUND");
    return receivedAmount;
  }


  // emit Redeem(_cToken, amount, underlying, receivedAmount);
  /**
  * @dev sell certain percent of Ctokens to Compound
  *
  * @param _percent      percent from 1 to 100
  * @param _cToken       cToken address
  */
  function compoundRedeemByPercent(uint _percent, address _cToken)
   external
   override
   returns(uint256)
  {
    uint256 receivedAmount = 0;

    uint256 amount = getPercentFromCTokenBalance(_percent, _cToken, msg.sender);

    // transfer amount from sender
    IERC20(_cToken).transferFrom(msg.sender, address(this), amount);

    // reedem
    if(_cToken == address(cEther)){
      // redeem compound ETH
      cEther.redeem(amount);
      // transfer received ETH back to fund
      receivedAmount = address(this).balance;
      (msg.sender).transfer(receivedAmount);

    }else{
      // redeem ERC20
      CToken cToken = CToken(_cToken);
      cToken.redeem(amount);
      // transfer received ERC20 back to fund
      address underlyingAddress = cToken.underlying();
      IERC20 underlying = IERC20(underlyingAddress);
      receivedAmount = underlying.balanceOf(address(this));
      underlying.transfer(msg.sender, receivedAmount);
    }

    require(receivedAmount > 0, "received amount can not be zerro");

    return receivedAmount;
  }

  /**
  * @dev return percent of compound cToken balance
  *
  * @param _percent       amount of ERC20 or ETH
  * @param _cToken        cToken address
  * @param _holder        address of cToken holder
  */
  function getPercentFromCTokenBalance(uint _percent, address _cToken, address _holder)
   public
   override
   view
   returns(uint256)
  {
    if(_percent == 100){
      return IERC20(_cToken).balanceOf(_holder);
    }
    else if(_percent > 0 && _percent < 100){
      uint256 currectBalance = IERC20(_cToken).balanceOf(_holder);
      return currectBalance.div(100).mul(_percent);
    }
    else{
      // not correct percent
      return 0;
    }
  }
}
