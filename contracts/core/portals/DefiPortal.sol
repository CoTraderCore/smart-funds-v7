// For support new Defi protocols
pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../yearn/IYearnToken.sol";
import "../interfaces/ITokensTypeStorage.sol";


contract DefiPortal {
  using SafeMath for uint256;

  address constant private ETH_TOKEN_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  // Contract for handle tokens types
  ITokensTypeStorage public tokensTypes;

  // Enum
  // NOTE: You can add a new type at the end, but DO NOT CHANGE this order
  enum DefiActions { YearnDeposit, YearnWithdraw }

  constructor(address _tokensTypes) public {
    tokensTypes = ITokensTypeStorage(_tokensTypes);
  }

  function callPayableProtocol(
    address[] memory tokensToSend,
    uint256[] memory amountsToSend,
    bytes memory _additionalData,
    bytes32[] memory _additionalArgs
  )
    external
    payable
    returns(
      string memory eventType,
      bytes memory eventData,
      address[] memory tokensReceived
    )
  {
    // there are no action for current DEFI payable protocol
    revert("Unknown DEFI action");
  }

  function callNonPayableProtocol(
    address[] memory tokensToSend,
    uint256[] memory amountsToSend,
    bytes memory _additionalData,
    bytes32[] memory _additionalArgs
  )
    external
    returns(
      string memory eventType,
      address[] memory tokensToReceive,
      uint256[] memory amountsToReceive
    )
  {
    if(uint(_additionalArgs[0]) == uint(DefiActions.YearnDeposit)){
      (tokensToReceive, amountsToReceive) = _YearnDeposit(
        tokensToSend[0],
        amountsToSend[0],
        _additionalData
      );
      eventType = "YEARN_DEPOSIT";
    }
    else if(uint(_additionalArgs[1]) == uint(DefiActions.YearnWithdraw)){
       (tokensToReceive, amountsToReceive) = _YearnWithdraw(
         tokensToSend[0],
         amountsToSend[0],
         _additionalData
        );
       eventType = "YEARN_WITHDRAW";
    }
    else{
      revert("Unknown DEFI action");
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


  // param _additionalData require address yTokenAddress, uint256 minReturn
  function _YearnDeposit(
    address tokenAddress,
    uint256 tokenAmount,
    bytes memory _additionalData
  )
    private
    returns(
    address[] memory tokensToReceive,
    uint256[] memory amountsToReceive
  )
  {
    // get yToken instance
    (address yTokenAddress, uint256 minReturn) = abi.decode(_additionalData, (address, uint256));
    IYearnToken yToken = IYearnToken(yTokenAddress);
    // transfer underlying from sender
    _transferFromSenderAndApproveTo(IERC20(tokenAddress), tokenAmount, yTokenAddress);
    // mint yToken
    yToken.deposit(tokenAmount);
    // get received tokens
    uint256 receivedYToken = IERC20(yTokenAddress).balanceOf(address(this));
    // min return check
    require(receivedYToken >= minReturn, "MIN_RETURN_FAIL");
    // send yToken to sender
    IERC20(yTokenAddress).transfer(msg.sender, receivedYToken);
    // send remains if there is some remains
    _sendRemains(IERC20(tokenAddress), msg.sender);
    // Update type
    // DEV NOTE don't need mark this tokens as YEARN assets, we can use 1inch ratio
    // for this token as for CRYPTOCURRENCY
    tokensTypes.addNewTokenType(yTokenAddress, "CRYPTOCURRENCY");
    // return data
    tokensToReceive = new address[](1);
    tokensToReceive[0] = tokenAddress;
    amountsToReceive = new uint256[](1);
    amountsToReceive[0] = receivedYToken;
  }


  // param _additionalData require  uint256 minReturn
  function _YearnWithdraw(
    address yTokenAddress,
    uint256 sharesAmount,
    bytes memory _additionalData
  )
    private
    returns(
    address[] memory tokensToReceive,
    uint256[] memory amountsToReceive
    )
  {
    (uint256 minReturn) = abi.decode(_additionalData, (uint256));
    IYearnToken yToken = IYearnToken(yTokenAddress);
    // transfer underlying from sender
    _transferFromSenderAndApproveTo(IERC20(yTokenAddress), sharesAmount, yTokenAddress);
    // mint yToken
    yToken.withdraw(sharesAmount);
    // get underlying address
    address underlyingToken = yToken.token();
    // get received tokens
    uint256 received = IERC20(underlyingToken).balanceOf(address(this));
    // min return check
    require(received >= minReturn, "MIN_RETURN_FAIL");
    // send underlying to sender
    IERC20(underlyingToken).transfer(msg.sender, received);
    // send remains if there is some remains
    _sendRemains(IERC20(yTokenAddress), msg.sender);
    // return data
    tokensToReceive = new address[](1);
    tokensToReceive[0] = underlyingToken;
    amountsToReceive = new uint256[](1);
    amountsToReceive[0] = received;
  }


  // Facilitates for send source remains
  function _sendRemains(IERC20 _source, address _receiver) private {
    // After the trade, any _source that exchangePortal holds will be sent back to msg.sender
    uint256 endAmount = (_source == IERC20(ETH_TOKEN_ADDRESS))
    ? address(this).balance
    : _source.balanceOf(address(this));

    // Check if we hold a positive amount of _source
    if (endAmount > 0) {
      if (_source == IERC20(ETH_TOKEN_ADDRESS)) {
        payable(_receiver).transfer(endAmount);
      } else {
        _source.transfer(_receiver, endAmount);
      }
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
