import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface PoolPortalInterface {
  function buyPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken
  )
  external
  payable;

  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken
  )
  external
  payable;

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
  returns(
    IERC20 BNTConnector,
    IERC20 ERCConnector
  );

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

  function getUniswapTokenAmountByETH(address _token, uint256 _amount)
  external
  view
  returns(uint256);

  function getTokenByUniswapExchange(address _exchange)
  external
  view
  returns(address);
}
