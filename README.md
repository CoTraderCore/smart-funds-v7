# smart-funds-v7

```
Status: not finished
```

# Run tests

```
NOTE: in separate console

0) npm i
1) npm run ganache  
2) truffle test
```

# Done

```
1) Made more flexible pools with the ability to add another dapp pool in future, not only Uniswap and Bancor
2) Bind platfromFee with managerFee
3) Add 2+ pool connectors
4) Provide events with additional data for profit verifier script
5) Remove Bancor ETH wrapper from portals for reduce Bancor ETH transactions gas cost
6) Recieve data like Bancor path, ratio ect via proxy getBancorData contract, for case if Bancor will update some method.
7) Made upgradable addresses of getBancorData contract in Pool and Exchnage portals
8) Return bytes32 additional args for buy and sell pools
9) Reduce 1inch gas cost in few times by get params offchain
10) Add merkle tree white list verification in ExchangePortal
```

# Todo
```
1) Add support for Bancor v2 pools new methods
3) Try reduce 1inch gas in ConvertPortal 
```

# Possible issue

```
1) Test returns pool data from pool portal in Ropsten
```


# Deploy note

```
Don't forget set new pool portal to permited type storage
```
