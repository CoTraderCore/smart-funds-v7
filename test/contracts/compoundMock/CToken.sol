pragma solidity ^0.6.12;

import "../tokens/Token.sol";

contract CToken is Token {
  address public underlying;

  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply, address _underlying)
    Token(_name, _symbol, _decimals, _totalSupply)
    public
  {
    // send all tokens from sender to this contract
    balances[msg.sender] = 0;
    balances[address(this)] = _totalSupply;

    // Initial ERC underlying
    underlying = _underlying;
  }

  function mint(uint mintAmount) external returns (uint) {
    require(ERC20(underlying).transferFrom(msg.sender, address(this), mintAmount),
    "NOT Provide ERC20 for mint cToken");
    balances[msg.sender] = balances[msg.sender].add(mintAmount);
    return mintAmount;
  }

  function redeem(uint redeemTokens) external returns (uint){
    _burn(msg.sender, redeemTokens);
    ERC20(underlying).transfer(msg.sender, redeemTokens);
  }

  function redeemUnderlying(uint redeemAmount) external returns (uint){
    _burn(msg.sender, redeemAmount);
    ERC20(underlying).transfer(msg.sender, redeemAmount);
  }

  function balanceOfUnderlying(address account) external view returns (uint){
    return ERC20(address(this)).balanceOf(account);
  }

  function _burn(address _who, uint256 _value) private {
    require(_value <= balances[_who]);
    balances[_who] = balances[_who].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
  }
}
