pragma solidity ^0.6.0;

/**
* This contract convert source ERC20 token to destanation token
* support sources 1INCH, COMPOUND, BANCOR/UNISWAP pools
*/

import "../interfaces/ExchangePortalInterface.sol";
import "../interfaces/PoolPortalInterface.sol";
import "../interfaces/ITokensTypeStorage.sol";
import "../interfaces/PermittedExchangesInterface.sol";
import "../interfaces/PermittedPoolsInterface.sol";
import "../../compound/CToken.sol";
import "../../oneInch/IOneSplitAudit.sol";
import "../../zeppelin-solidity/contracts/access/Ownable.sol";

contract ConvertPortal is Ownable{
  address constant private ETH_TOKEN_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  bytes32[] private BYTES32_EMPTY_ARRAY = new bytes32[](0);
  uint256[] private UINT_EMPTY_ARRAY = new uint256[](0);
  address public CEther;
  address public sUSD;
  ExchangePortalInterface public exchangePortal;
  PoolPortalInterface public poolPortal;
  PermittedExchangesInterface public permittedExchanges;
  PermittedPoolsInterface public permittedPools;
  ITokensTypeStorage  public tokensTypes;
  IOneSplitAudit public oneInch;

  /**
  * @dev contructor
  *
  * @param _exchangePortal         address of exchange portal
  * @param _poolPortal             address of pool portal
  * @param _permittedExchanges     address of permittedExchanges
  * @param _permittedPools         address of pool portal
  * @param _tokensTypes            address of the tokens type storage
  * @param _CEther                 address of Compound ETH wrapper
  * @param _oneInch                address of 1inch main contract
  */
  constructor(
    address _exchangePortal,
    address _poolPortal,
    address _permittedExchanges,
    address _permittedPools,
    address _tokensTypes,
    address _CEther,
    address _oneInch
    )
    public
  {
    exchangePortal = ExchangePortalInterface(_exchangePortal);
    poolPortal = PoolPortalInterface(_poolPortal);
    permittedExchanges = PermittedExchangesInterface(_permittedExchanges);
    permittedPools = PermittedPoolsInterface(_permittedPools);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
    CEther = _CEther;
    oneInch = IOneSplitAudit(_oneInch);
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
      receivedAmount = convertCryptocurency(_source, _sourceAmount, _destination, false);
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
      destAmount = convertCryptocurency(underlyingAddress, underlyingAmount, _destination, true);
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
      BYTES32_EMPTY_ARRAY,
      "0x"
    );

    // convert pool connectors to destanation
    // get erc20 connector address
    address ERCConnector = poolPortal.getTokenByUniswapExchange(_source);
    uint256 ERCAmount = IERC20(ERCConnector).balanceOf(address(this));

    // convert ERC20 connector via 1inch if destination != ERC20 connector
    if(ERCConnector != _destination){
      convertCryptocurency(ERCConnector, ERCAmount, _destination, true);
    }

    // if destanation != ETH, convert ETH also
    if(_destination != ETH_TOKEN_ADDRESS){
      uint256 ETHAmount = address(this).balance;
      convertCryptocurency(ETH_TOKEN_ADDRESS, ETHAmount, _destination, true);
    }

    // return received amount
    if(_destination == ETH_TOKEN_ADDRESS){
      return address(this).balance;
    }else{
      return IERC20(_destination).balanceOf(address(this));
    }
  }

  // helper for convert standrad crypto assets
  function convertCryptocurency(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    bool    _isLocalConvert
    )
    private
    returns(uint256)
  {
    (, uint256[] memory distribution) = oneInch.getExpectedReturn(
      IERC20(_source),
      IERC20(_destination),
      _sourceAmount,
      10,
      0);

    bytes memory additionalData = abi.encode(10, distribution);

    // Convert crypto via 1inch aggregator
    uint256 destAmount = 0;
    if(_source == ETH_TOKEN_ADDRESS){
      // Trade ETH
      destAmount = exchangePortal.trade.value(_sourceAmount)(
        IERC20(_source),
        _sourceAmount,
        IERC20(_destination),
        2,
        BYTES32_EMPTY_ARRAY,
        UINT_EMPTY_ARRAY,
        additionalData,
        false
      );
    }else{
      // Approve ERC 20

      // if it's local convert just approve
      if(_isLocalConvert){
        IERC20(_source).approve(address(exchangePortal), _sourceAmount);
      }
      // if it's not local сщтмуке transfer from sender and approve
      else{
        _transferFromSenderAndApproveTo(IERC20(_source), _sourceAmount, address(exchangePortal));
      }

      // Trade ERC20
      destAmount = exchangePortal.trade(
        IERC20(_source),
        _sourceAmount,
        IERC20(_destination),
        2,
        BYTES32_EMPTY_ARRAY,
        UINT_EMPTY_ARRAY,
        additionalData,
        false
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
      UINT_EMPTY_ARRAY,
      "0x",
      false
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

  // owner can change oneInch
  function setNewOneInch(address _oneInch) external onlyOwner {
    oneInch = IOneSplitAudit(_oneInch);
  }

  /**
  * @dev Sets a new default ExchangePortal address
  *
  * @param _newExchangePortalAddress    Address of the new exchange portal to be set
  */
  function setExchangePortalAddress(address _newExchangePortalAddress) external onlyOwner {
    // Require that the new exchange portal is permitted by permittedExchanges
    require(permittedExchanges.permittedAddresses(_newExchangePortalAddress));

    exchangePortal = ExchangePortalInterface(_newExchangePortalAddress);
  }

  /**
  * @dev Sets a new default Portal Portal address
  *
  * @param _poolPortalAddress    Address of the new pool portal to be set
  */
  function setPoolPortalAddress (address _poolPortalAddress) external onlyOwner {
    // Require that the new pool portal is permitted by permittedPools
    require(permittedPools.permittedAddresses(_poolPortalAddress));

    poolPortal = PoolPortalInterface(_poolPortalAddress);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}
}
