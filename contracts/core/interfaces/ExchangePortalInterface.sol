import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface ExchangePortalInterface {

  event Trade(address src, uint256 srcAmount, address dest, uint256 destReceived);

  function trade(
    IERC20 _source,
    uint256 _sourceAmount,
    IERC20 _destination,
    uint256 _type,
    uint256[] calldata _distribution,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
    external
    payable
    returns (uint256);

  function compoundRedeemByPercent(uint _percent, address _cToken) external returns(uint256);

  function compoundMint(uint256 _amount, address _cToken) external payable returns(uint256);

  function getPercentFromCTokenBalance(uint _percent, address _cToken, address _holder)
   external
   view
   returns(uint256);

  function getValue(address _from, address _to, uint256 _amount) external view returns (uint256);

  function getTotalValue(
    address[] calldata _fromAddresses,
    uint256[] calldata _amounts,
    address _to
    )
    external
    view
   returns (uint256);

   function getCTokenUnderlying(address _cToken) external view returns(address);
}
