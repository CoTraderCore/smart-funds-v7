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
1) Made more flexible pools with the ability to add another dapp pool in future,
not only Uniswap and Bancor.

2) Bind platfromFee with managerFee.

3) Add 2+ pool connectors.

4) Provide events with additional data for profit verifier script.

5) Remove Bancor ETH wrapper from portals for reduce Bancor ETH transactions gas cost.

6) Recieve data like Bancor path, ratio ect via proxy getBancorData contract,
for case if Bancor will update some method.

7) Made upgradable addresses of getBancorData contract in Pool and Exchnage portals.

8) Return bytes32 additional args for buy and sell pools.

9) Reduce 1inch gas cost in few times by get params offchain.

10) Add merkle tree tokens white list verification in ExchangePortal.

11) Add support for new Bancor type 1 and 2 pools new methods.

12) Pass data for buying old Bancor and Uniswap v1 pools offchain,
for reduce gas cost.

13) Remove Convert portal.
```

# Todo
```
1) Add Uniswap v2 pools
2) Test Bancor pool v >= 28 and type 2
```

# Possible issue

```
Test returns pool data from pool portal in Ropsten
```


# Deploy note

```
Don't forget set new pool and exchange portals to permited type storage
```
