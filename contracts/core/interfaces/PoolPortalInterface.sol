import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface PoolPortalInterface {
  function buyPool
  (
    uint256 _amount,
    uint _type,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  payable
  returns(uint256 poolAmountReceive);

  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionData
  )
  external
  payable
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  );

  function getDataForBuyingPool(IERC20 _poolToken, uint _type, uint256 _amount)
    external
    view
    returns(
      address[] memory connectorsAddress,
      uint256[] memory connectorsAmount
  );

  function getBacorConverterAddressByRelay(address relay)
  external
  view
  returns(address converter);

  function getBancorConnectorsAmountByRelayAmount
  (
    uint256 _amount,
    IERC20 _relay
  )
  external view returns(uint256 bancorAmount, uint256 connectorAmount);

  function getBancorConnectorsByRelay(address relay)
  external
  view
  returns(address[] memory connectorsAddress);

  function getBancorRatio(address _from, address _to, uint256 _amount)
  external
  view
  returns(uint256);

  function getUniswapConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
  external
  view
  returns(uint256 ethAmount, uint256 ercAmount);

  function getUniswapV2ConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
  external
  view
  returns(
    uint256 tokenAmountOne,
    uint256 tokenAmountTwo,
    address tokenAddressOne,
    address tokenAddressTwo
  );

  function getUniswapTokenAmountByETH(address _token, uint256 _amount)
  external
  view
  returns(uint256);

  function getTokenByUniswapExchange(address _exchange)
  external
  view
  returns(address);
}
