// For support new Defi protocols
pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

import "../interfaces/ITokensTypeStorage.sol";
import "../../compound/CToken.sol";
import "../../compound/CEther.sol";


contract DefiPortal {
  using SafeMath for uint256;

  // COMPOUND ETH wrapper address
  CEther public cEther;
  address constant private ETH_TOKEN_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  // Contract for handle tokens types
  ITokensTypeStorage public tokensTypes;

  // Enum
  // NOTE: You can add a new type at the end, but DO NOT CHANGE this order
  enum DefiActions { CompoundLoan, CompoundReedem }

  constructor(address _cEther, address _tokensTypes) public {
    cEther = CEther(_cEther);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
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
    if(uint(_additionalArgs[0]) == uint(DefiActions.CompoundLoan)){
      (tokensSent,
       tokensReceived,
       amountSent,
       amountReceived) = compoundMint(_data);

       eventType = "COMPOUND_LOAN";
    }
    else{
      revert("Unknown action");
    }
  }

  function callNonPayableProtocol(
    bytes memory _data,
    bytes32[] memory _additionalArgs
  )
    external
    returns(
      string memory eventType,
      address[] memory tokensSent,
      address[] memory tokensReceived,
      uint256[] memory amountSent,
      uint256[] memory amountReceived
    )
  {
    if(uint(_additionalArgs[0]) == uint(DefiActions.CompoundLoan)){
     (tokensSent,
      tokensReceived,
      amountSent,
      amountReceived) = compoundMint(_data);

      eventType = "COMPOUND_LOAN";
    }
    else if(uint(_additionalArgs[1]) == uint(DefiActions.CompoundReedem)){
      (tokensSent,
       tokensReceived,
       amountSent,
       amountReceived) = compoundRedeemByPercent(_data);

      eventType = "COMPOUND_REDEEM";
    }
    else{
      revert("Unknown action");
    }
  }

  // for new DEFI protocols Exchange portal get value here
  function getValue(
    address _from,
    address _to,
    uint256 _amount
  )
   public
   view
   returns(uint256)
  {
    return 0;
  }


  // get underlying by cToken
  function getCTokenUnderlying(address _cToken)
    public
    view
    returns(address)
  {
    return CToken(_cToken).underlying();
  }


  /**
  * @dev buy Compound cTokens
  */
  function compoundMint(bytes memory _data)
   private
   returns(
     address[] memory tokensSent,
     address[] memory tokensReceived,
     uint256[] memory amountSent,
     uint256[] memory amountReceived
   )
  {
    uint256 receivedAmount;
    address underlyingAddress;

    (uint256 _amount,
     address _cToken) = abi.decode(_data, (uint256, address));

    if(_cToken == address(cEther)){
      underlyingAddress = ETH_TOKEN_ADDRESS;
      // mint cETH
      cEther.mint.value(_amount)();
      // transfer received cETH back to fund
      receivedAmount = cEther.balanceOf(address(this));
      cEther.transfer(msg.sender, receivedAmount);
    }else{
      // mint cERC20
      CToken cToken = CToken(_cToken);
      underlyingAddress = cToken.underlying();
      _transferFromSenderAndApproveTo(IERC20(underlyingAddress), _amount, address(_cToken));
      cToken.mint(_amount);
      // transfer received cERC back to fund
      receivedAmount = cToken.balanceOf(address(this));
      cToken.transfer(msg.sender, receivedAmount);
    }
    // Additional check
    require(receivedAmount > 0, "Comp cToken cant be 0");
    // Update token type
    tokensTypes.addNewTokenType(_cToken, "COMPOUND");

    // return DATA
    tokensSent = new address[](1);
    tokensSent[0] = underlyingAddress;
    tokensReceived = new address[](1);
    tokensReceived[0] = _cToken;
    amountSent = new uint256[](1);
    amountSent[0] = _amount;
    amountReceived = new uint256[](1);
    amountReceived[0] = receivedAmount;
  }


  /**
  * @dev sell certain percent of Ctokens to Compound
  */
  function compoundRedeemByPercent(bytes memory _data)
   private
   returns(
     address[] memory tokensSent,
     address[] memory tokensReceived,
     uint256[] memory amountSent,
     uint256[] memory amountReceived
   )
  {
    (uint256 _percent,
     address _cToken) = abi.decode(_data, (uint256, address));

    uint256 receivedAmount;
    address underlyingAddress;
    uint256 amount = getPercentFromCTokenBalance(_percent, _cToken, msg.sender);

    // transfer amount from sender
    IERC20(_cToken).transferFrom(msg.sender, address(this), amount);

    // reedem
    if(_cToken == address(cEther)){
      underlyingAddress = ETH_TOKEN_ADDRESS;
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
      underlyingAddress = cToken.underlying();
      IERC20 underlying = IERC20(underlyingAddress);
      receivedAmount = underlying.balanceOf(address(this));
      underlying.transfer(msg.sender, receivedAmount);
    }
    // Additional check
    require(receivedAmount > 0, "Comp underlying cant be 0");

    // return DATA
    tokensSent = new address[](1);
    tokensSent[0] = _cToken;
    tokensReceived = new address[](1);
    tokensReceived[0] = underlyingAddress;
    amountSent = new uint256[](1);
    amountSent[0] = amount;
    amountReceived = new uint256[](1);
    amountReceived[0] = receivedAmount;
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

  /**
  * @dev Transfers tokens to this contract and approves them to another address
  *
  * @param _source          Token to transfer and approve
  * @param _sourceAmount    The amount to transfer and approve (in _source token)
  * @param _to              Address to approve to
  */
  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));
    // reset previos approve because some tokens require allowance 0
    _source.approve(_to, 0);
    // approve
    _source.approve(_to, _sourceAmount);
  }
}
