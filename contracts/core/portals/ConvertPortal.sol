pragma solidity ^0.6.0;

/**
* This contract convert source ERC20 token to destanation token
* support sources 1INCH, COMPOUND, BANCOR/UNISWAP pools
*/

import "../interfaces/ExchangePortalInterface.sol";
import "../interfaces/PoolPortalInterface.sol";
import "../interfaces/ITokensTypeStorage.sol";
import "../../compound/CToken.sol";


contract ConvertPortal {
  address constant private ETH_TOKEN_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  bytes32[] private BYTES32_EMPTY_ARRAY = new bytes32[](0);
  address public CEther;
  address public sUSD;
  ExchangePortalInterface public exchangePortal;
  PoolPortalInterface public poolPortal;
  ITokensTypeStorage  public tokensTypes;

  /**
  * @dev contructor
  *
  * @param _exchangePortal         address of exchange portal
  * @param _poolPortal             address of pool portal
  * @param _tokensTypes            address of the tokens type storage
  * @param _CEther                 address of Compound ETH wrapper
  */
  constructor(
    address _exchangePortal,
    address _poolPortal,
    address _tokensTypes,
    address _CEther
    )
    public
  {
    exchangePortal = ExchangePortalInterface(_exchangePortal);
    poolPortal = PoolPortalInterface(_poolPortal);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
    CEther = _CEther;
  }

  // convert CRYPTOCURRENCY, COMPOUND, BANCOR/UNISWAP pools to _destination asset
  function convert(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    address _receiver
  )
    external
    payable
  {
    // no need continue convert for not correct input data
    if(_sourceAmount <= 0 || _source == _destination)
      return;

    uint256 receivedAmount = 0;
    // convert assets
    if(tokensTypes.getType(_source) == bytes32("CRYPTOCURRENCY")){
      receivedAmount = convertCryptocurency(_source, _sourceAmount, _destination);
    }
    else if (tokensTypes.getType(_source) == bytes32("BANCOR_ASSET")){
      receivedAmount = convertBancorPool(_source, _sourceAmount, _destination);
    }
    else if (tokensTypes.getType(_source) == bytes32("UNISWAP_POOL")){
      receivedAmount = convertUniswapPool(_source, _sourceAmount, _destination);
    }
    else if (tokensTypes.getType(_source) == bytes32("COMPOUND")){
      receivedAmount = convertCompound(_source, _sourceAmount, _destination);
    }
    else {
      // Unknown type
      revert("Unknown token type");
    }

    // send assets to _receiver
    if (_destination == ETH_TOKEN_ADDRESS) {
      payable(_receiver).transfer(receivedAmount);
    } else {
      // transfer tokens received to sender
      IERC20(_destination).transfer(_receiver, receivedAmount);
    }

    // After the trade, any _source that exchangePortal holds will be sent back to msg.sender
    uint256 endAmount = (_source == ETH_TOKEN_ADDRESS)
    ? address(this).balance
    : IERC20(_source).balanceOf(address(this));

    // Check if we hold a positive amount of _source
    if (endAmount > 0) {
      if (_source == ETH_TOKEN_ADDRESS) {
        payable(_receiver).transfer(endAmount);
      } else {
        IERC20(_source).transfer(_receiver, endAmount);
      }
    }
  }

  // helper for convert Compound asset
  // _source - should be Compound token
  function convertCompound(address _source, uint256 _sourceAmount, address _destination)
    private
    returns(uint256)
  {
    // step 0 transfer compound asset from sender
    IERC20(_source).transferFrom(msg.sender, address(this), _sourceAmount);

    // step 1 convert cToken to underlying
    CToken(_source).redeem(_sourceAmount);

    // step 2 get underlying address and received underlying amount
    address underlyingAddress = (_source == CEther)
    ? ETH_TOKEN_ADDRESS
    : CToken(_source).underlying();

    uint256 underlyingAmount = (_source == CEther)
    ? address(this).balance
    : IERC20(underlyingAddress).balanceOf(address(this));

    // step 3 convert underlying to destination if _destination != underlyingAddress
    if(_destination != underlyingAddress){
      uint256 destAmount = 0;
      // convert via 1inch
      // Convert ETH
      if(underlyingAddress == ETH_TOKEN_ADDRESS){
        destAmount = exchangePortal.trade.value(underlyingAmount)(
          IERC20(underlyingAddress),
          underlyingAmount,
          IERC20(_destination),
          2,
          BYTES32_EMPTY_ARRAY,
          "0x"
        );
      }
      // Convert ERC20
      else{
        IERC20(underlyingAddress).approve(address(exchangePortal), underlyingAmount);
        destAmount = exchangePortal.trade(
          IERC20(underlyingAddress),
          underlyingAmount,
          IERC20(_destination),
          2,
          BYTES32_EMPTY_ARRAY,
          "0x"
        );
      }
      return destAmount;
    }
    else{
      return underlyingAmount;
    }

  }

  // helper for convert Unswap asset
  // _source - should be Uni pool
  function convertUniswapPool(address _source, uint256 _sourceAmount, address _destination)
    private
    returns(uint256)
  {
    // sell pool
    _transferFromSenderAndApproveTo(IERC20(_source), _sourceAmount, address(poolPortal));

    poolPortal.sellPool(
      _sourceAmount,
      1, // type Uniswap
      IERC20(_source),
      BYTES32_EMPTY_ARRAY
    );

    // convert pool connectors to destanation
    // get erc20 connector address
    address ERCConnector = poolPortal.getTokenByUniswapExchange(_source);
    uint256 ERCAmount = IERC20(ERCConnector).balanceOf(address(this));

    // convert ERC20 connector via 1inch if destination != ERC20 connector
    if(ERCConnector != _destination){
      IERC20(ERCConnector).approve(address(exchangePortal), ERCAmount);
      exchangePortal.trade(
        IERC20(ERCConnector),
        ERCAmount,
        IERC20(_destination),
        2, // type 1inch
        BYTES32_EMPTY_ARRAY,
        "0x"
      );
    }

    // if destanation != ETH, convert ETH also
    if(_destination != ETH_TOKEN_ADDRESS){
      uint256 ETHAmount = address(this).balance;
      exchangePortal.trade.value(ETHAmount)(
        IERC20(ETH_TOKEN_ADDRESS),
        ETHAmount,
        IERC20(_destination),
        2, // type 1inch
        BYTES32_EMPTY_ARRAY,
        "0x"
      );
    }

    // return received amount
    if(_destination == ETH_TOKEN_ADDRESS){
      return address(this).balance;
    }else{
      return IERC20(_destination).balanceOf(address(this));
    }
  }

  // helper for convert standrad crypto assets
  function convertCryptocurency(address _source, uint256 _sourceAmount, address _destination)
    private
    returns(uint256)
  {
    // Convert crypto via 1inch aggregator
    uint256 destAmount = 0;
    if(_source == ETH_TOKEN_ADDRESS){
      destAmount = exchangePortal.trade.value(_sourceAmount)(
        IERC20(_source),
        _sourceAmount,
        IERC20(_destination),
        2,
        BYTES32_EMPTY_ARRAY,
        "0x"
      );
    }else{
      _transferFromSenderAndApproveTo(IERC20(_source), _sourceAmount, address(exchangePortal));
      destAmount = exchangePortal.trade(
        IERC20(_source),
        _sourceAmount,
        IERC20(_destination),
        2,
        BYTES32_EMPTY_ARRAY,
        "0x"
      );
    }
    return destAmount;
  }

  // helper for convert Bancor pools asset
  // _source - should be Bancor pool
  function convertBancorPool(address _source, uint256 _sourceAmount, address _destination)
    private
    returns(uint256)
  {
    _transferFromSenderAndApproveTo(IERC20(_source), _sourceAmount, address(exchangePortal));
    // Convert BNT pools just via Bancor DEX
    uint256 destAmount = exchangePortal.trade(
      IERC20(_source),
      _sourceAmount,
      IERC20(_destination),
      1,
      BYTES32_EMPTY_ARRAY,
      "0x"
    );

    return destAmount;
  }

  /**
  * @dev Transfers tokens to this contract and approves them to another address
  *
  * @param _source          Token to transfer and approve
  * @param _sourceAmount    The amount to transfer and approve (in _source token)
  * @param _to              Address to approve to
  */
  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount), "Can not transfer from");

    _source.approve(_to, _sourceAmount);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}
}
