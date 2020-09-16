// For support new Defi protocols
pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

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
    bytes memory _data,
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
    bytes memory _data,
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

      eventType = "YEARN_DEPOSIT";
    }
    else if(uint(_additionalArgs[1]) == uint(DefiActions.YearnWithdraw)){

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

  function _YearnDeposit()
    private
    returns(
    address[] memory tokensToReceive,
    uint256[] memory amountsToReceive
    )
  {

  }

  function _YearnWithdraw() private returns(
    address[] memory tokensToReceive,
    uint256[] memory amountsToReceive
    )
  {

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
