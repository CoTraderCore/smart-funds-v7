pragma solidity ^0.6.12;

import "../tokens/Token.sol";


contract CEther is Token{
  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply)
    Token(_name, _symbol, _decimals, _totalSupply)
    public
  {
    // send all tokens from sender to this contract
    balances[msg.sender] = 0;
    balances[address(this)] = _totalSupply;
  }

  function mint() external payable {
    require(msg.value > 0, 'You need provide ETH for mint cETH');
    balances[msg.sender] = balances[msg.sender].add(msg.value);
  }

  function redeem(uint redeemTokens) external returns (uint){
    _burn(msg.sender, redeemTokens);
    msg.sender.transfer(redeemTokens);
  }

  function redeemUnderlying(uint redeemAmount) external returns (uint){
    _burn(msg.sender, redeemAmount);
    msg.sender.transfer(redeemAmount);
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
