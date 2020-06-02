import "./PermittedExchangesInterface.sol";
import "./PermittedPoolsInterface.sol";
import "./PermittedStablesInterface.sol";

contract ISmartFundRegistry {
  // Compound addresses
  address public cEther;
  address public Comptroller;
  address public PriceOracle;

  // Addresses of portals
  address public poolPortalAddress;
  address public exchangePortalAddress;

  // Address of stable coin
  address public stableCoinAddress;

  // The Smart Contract which stores the addresses of all the authorized Exchange Portals
  PermittedExchangesInterface public permittedExchanges;
  // The Smart Contract which stores the addresses of all the authorized Pool Portals
  PermittedPoolsInterface public permittedPools;
  // The Smart Contract which stores the addresses of all the authorized stable coins
  PermittedStablesInterface public permittedStables;
}
