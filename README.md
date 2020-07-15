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
1) Optimized core fund logic
2) Made more flexible pool with the ability to add another dapp pool
3) Bind platfromFee with managerFee
4) Add 2+ pool connectors
5) Provide events with additional data for profit verifier script
6) Remove Bancor ETH wrapper from portals
7) Recieve data like Bancor path, ratio ect via proxy getBancorData contract, for case if Bancor will update some method.
8) Made upgradable addresses of getBancorData contract in Pool and Exchnage portals
```

# Todo
```
1) Add support for Bancor v2 pools
2) Reduce 1inch gas cost in few times by get params offchain
```

# Possible issue

```
1) Test returns pool data from pool portal in Ropsten
```


# Deploy note

```
Don't forget set new pool portal to permited type storage
```
