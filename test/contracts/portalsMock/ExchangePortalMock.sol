pragma solidity ^0.6.12;

import "../../../contracts/zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../../contracts/core/interfaces/ITokensTypeStorage.sol";
import "../../../contracts/core/interfaces/IMerkleTreeTokensVerification.sol";

import "../compoundMock/CEther.sol";
import "../compoundMock/CToken.sol";

contract ExchangePortalMock {

  using SafeMath for uint256;
  ITokensTypeStorage public tokensTypes;
  // Contract for merkle tree white list verification
  IMerkleTreeTokensVerification public merkleTreeWhiteList;

  // This contract recognizes ETH by this address, airswap recognizes ETH as address(0x0)
  IERC20 constant private ETH_TOKEN_ADDRESS = IERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  address constant private NULL_ADDRESS = address(0);
  // multiplyer and divider are used to set prices. X ether = X*(mul/div) token,
  // similarly X token = X*(div/mul) ether for every token where X is the amount
  uint256 public mul;
  uint256 public div;
  address public stableCoinAddress;
  bool public stopTransfer;

  CEther public cEther;

  // Enum
  enum ExchangeType { Paraswap, Bancor, OneInch }

  event Trade(address trader, address src, uint256 srcAmount, address dest, uint256 destReceived, uint8 exchangeType);

  constructor(
    uint256 _mul,
    uint256 _div,
    address _stableCoinAddress,
    address _cETH,
    address _tokensTypes,
    address _merkleTreeWhiteList
    )
    public
  {
    mul = _mul;
    div = _div;
    stableCoinAddress = _stableCoinAddress;
    cEther = CEther(_cETH);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
    merkleTreeWhiteList = IMerkleTreeTokensVerification(_merkleTreeWhiteList);
  }

  function trade(
    IERC20 _source,
    uint256 _sourceAmount,
    IERC20 _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    bool _verifyDestanation
  ) external payable returns (uint256) {
    require(_source != _destination);

    uint256 receivedAmount;

    // throw if destanation token not in white list
    if(_verifyDestanation)
      _verifyToken(address(_destination), _proof, _positions);

    // check ETH payable case
    if (_source == ETH_TOKEN_ADDRESS) {
      require(msg.value == _sourceAmount);
    } else {
      require(msg.value == 0);
    }

    if (_type == uint(ExchangeType.Paraswap)) {
      // Trade via Paraswap
      receivedAmount = _tradeViaParaswapMock(_source, _destination, _sourceAmount, _additionalData);
    }
    else if (_type == uint(ExchangeType.Bancor)) {
      // Trade via Bancor (We can add special logic fo Bancor here)
      receivedAmount = _trade(_source, _destination, _sourceAmount);
    }
    else if (_type == uint(ExchangeType.OneInch)) {
      // Trade via 1inch
      receivedAmount = _tradeViaOneInchMock(_source, _destination, _sourceAmount, _additionalData);
    }
    else {
      // unknown exchange type
      revert();
    }

    // transfer asset B back to sender
    if (_destination == ETH_TOKEN_ADDRESS) {
      (msg.sender).transfer(receivedAmount);
    } else {
      // transfer tokens received to sender
      _destination.transfer(msg.sender, receivedAmount);
    }


    emit Trade(msg.sender, address(_source), _sourceAmount, address(_destination), receivedAmount, uint8(_type));

    return receivedAmount;
  }

  // Mock for trade via Bancor, Paraswap, OneInch
  // This DEXs has the same logic
  // Transfer asset A from fund and send asset B back to fund
  function _trade(IERC20 _source, IERC20 _destination, uint256 _sourceAmount)
   private
   returns(uint256 receivedAmount)
  {
    // we can broke transfer for tests
    if(!stopTransfer){
      // transfer asset A from sender
      if (_source == ETH_TOKEN_ADDRESS) {
        receivedAmount = getValue(address(_source), address(_destination), _sourceAmount);
      } else {
        _transferFromSenderAndApproveTo(_source, _sourceAmount, NULL_ADDRESS);
        receivedAmount = getValue(address(_source), address(_destination), _sourceAmount);
      }
    }else{
      receivedAmount = 0;
    }

    setTokenType(address(_destination), "CRYPTOCURRENCY");
  }

  function _tradeViaOneInchMock(
    IERC20 _source,
    IERC20 _destination,
    uint256 _sourceAmount,
    bytes calldata _additionalData
  )
    private
    returns(uint256)
  {
    // test decode params
    (uint256 flags,
     uint256[] memory _distribution) = abi.decode(_additionalData, (uint256, uint256[]));

    // check params
    require(flags > 0, "Not correct flags param for 1inch aggregator");
    require(_distribution.length > 0, "Not correct _distribution param for 1inch aggregator");

    return _trade(_source, _destination, _sourceAmount);
  }


  function _tradeViaParaswapMock(
    IERC20 _source,
    IERC20 _destination,
    uint256 _sourceAmount,
    bytes calldata _additionalData
  )
    private
    returns(uint256)
  {
    // Test decode correct params
    (uint256 minDestinationAmount,
     address[] memory callees,
     uint256[] memory startIndexes,
     uint256[] memory values,
     uint256 mintPrice,
     bytes memory exchangeData) = abi.decode(
       _additionalData,
       (uint256, address[], uint256[], uint256[], uint256, bytes)
     );

     // check params
     require(minDestinationAmount > 0, 'Not corerct minDestinationAmount param for Paraswap');
     require(callees.length > 0, 'Not corerct callees param for Paraswap');
     require(startIndexes.length  > 0, 'Not corerct startIndexes param for Paraswap');
     require(values.length  > 0, 'Not corerct values param for Paraswap');
     require(mintPrice > 0, 'Not corerct mintPrice param for Paraswap');

     return _trade(_source, _destination, _sourceAmount);
  }

  // Facilitates for verify destanation token input (check if token in merkle list or not)
  // revert transaction if token not in list
  function _verifyToken(
    address _destination,
    bytes32 [] memory proof,
    uint256 [] memory positions)
    private
  {
    bool status = merkleTreeWhiteList.verify(_destination, proof, positions);

    if(!status)
      revert("Dest not in white list");
  }


  // Possibilities:
  // * kyber.getExpectedRate
  // * kyber.findBestRate
  function getValue(address _from, address _to, uint256 _amount) public view returns (uint256) {
    // ETH case (can change rate)
    if (_to == address(ETH_TOKEN_ADDRESS)) {
      return _amount.mul(div).div(mul);
    }
    else if (_from == address(ETH_TOKEN_ADDRESS)) {
      return _amount.mul(mul).div(div);
    }
    // DAI Case (can change rate)
    else if(_to == stableCoinAddress) {
      return _amount.mul(div).div(mul);
    }
    else if(_from == stableCoinAddress) {
      return _amount.mul(mul).div(div);
    }
    // ERC case
    else {
      return _amount;
    }
  }

  // for mock 1 cETH = 1 ETH, 1 cERC20 = 1 ERC20
  function compoundRedeemByPercent(uint _percent, address _cToken)
   external
   returns(uint256)
  {
    uint256 receivedAmount = 0;

    uint256 amount = (_percent == 100)
    // if 100 return all
    ? IERC20(address(_cToken)).balanceOf(msg.sender)
    // else calculate percent
    : getPercentFromCTokenBalance(_percent, address(_cToken), msg.sender);

    // transfer amount from sender
    IERC20(_cToken).transferFrom(msg.sender, address(this), amount);

    // reedem
    if(_cToken == address(cEther)){
      // redeem compound ETH
      cEther.redeem(amount);
      // transfer received ETH back to fund
      receivedAmount = amount;
      (msg.sender).transfer(amount);

    }else{
      // redeem IERC20
      CToken cToken = CToken(_cToken);
      cToken.redeem(amount);
      // transfer received IERC20 back to fund
      address underlyingAddress = cToken.underlying();
      IERC20 underlying = IERC20(underlyingAddress);
      receivedAmount = amount;
      underlying.transfer(msg.sender, amount);
    }

    return receivedAmount;
  }

  /**
  * @dev buy Compound cTokens
  *
  * @param _amount       amount of ERC20 or ETH
  * @param _cToken       cToken address
  */
  function compoundMint(uint256 _amount, address _cToken)
   external
   payable
   returns(uint256)
  {
    uint256 receivedAmount = 0;
    if(_cToken == address(cEther)){
      // mint cETH
      cEther.mint.value(_amount)();
      // transfer received cETH back to fund
      receivedAmount = _amount;
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

    setTokenType(_cToken, "COMPOUND");

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
  view
  returns(uint256)
  {
    if(_percent > 0 && _percent <= 100){
      uint256 currectBalance = IERC20(_cToken).balanceOf(_holder);
      return currectBalance.div(100).mul(_percent);
    }
    else{
      // not correct percent
      return 0;
    }
  }

  function getCTokenUnderlying(address _cToken) public view returns(address){
    return CToken(_cToken).underlying();
  }

  // get the total value of multiple tokens and amounts in one go
  function getTotalValue(address[] memory _fromAddresses, uint256[] memory _amounts, address _to) public view returns (uint256) {
    uint256 sum = 0;

    for (uint256 i = 0; i < _fromAddresses.length; i++) {
      sum = sum.add(getValue(_fromAddresses[i], _to, _amounts[i]));
    }

    return sum;
  }

  function setRatio(uint256 _mul, uint256 _div) public {
    mul = _mul;
    div = _div;
  }


  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));
    // reset previos approve because some tokens require allowance 0
    _source.approve(_to, 0);
    // approve 
    _source.approve(_to, _sourceAmount);
  }

  function changeStopTransferStatus(bool _status) public {
    stopTransfer = _status;
  }


  function setTokenType(address _token, string memory _type) private {
    // no need add type, if token alredy registred
    if(tokensTypes.isRegistred(_token))
      return;

    tokensTypes.addNewTokenType(_token,  _type);
  }

  function pay() public payable {}

  fallback() external payable {}
}
