# Run tests

```
NOTE: in separate console

0) npm i
1) npm run ganache  
2) truffle test
```

# Updates 

```
1) Made more flexible pools with the ability to add another dapp pool in future,
not only Uniswap and Bancor.

2) Bind platfromFee with managerFee.

3) Add 2+ pool connectors.

4) Provide events with additional data for profit verifier script.

5) Remove Bancor ETH wrapper from portals for reduce Bancor ETH transactions gas cost.

6) Recieve data like Bancor path, ratio ect via proxy getBancorData contract,
for case if Bancor will update some method name.

7) Made upgradable addresses of getBancorData contract in Pool and Exchnage portals.

8) Return bytes32 additional args for buy and sell pools.

9) Reduce 1inch gas cost in few times by get params offchain.

10) Add merkle tree tokens white list verification in ExchangePortal.

11) Add support for new Bancor type 1 and 2 pools new methods.

12) Pass data for buying old Bancor and Uniswap v1 pools offchain,
for reduce gas cost.

13) Remove Convert portal.

14) Add New Bancor pools type 1 and 2.

15) Add Uniswap v2 pools.

16) Add Balancer pools.

17) Fix bug in ExchangePortal.getValue for CETH in ETH fund (from == to return input)

18) Fix protect from sending 0 assets in withdraw

19) Add DEFI portal for support new protocols without deploy new version of fund

20) Remove Compound logic from fund to Defi portal

21) Add one Global permitted contract for Exchange, Pool, Defi, Stable coins portal

22) Add Yearn Finance support

23) Add full and light funds factories
```


# Possible issue

```
Test returns events pool data from pool portal in Rinkeby for verifier script

Exchange Portal v7 not has incompatibility with older versions
```


# Mainent deploy note

```
Don't forget set new pool and exchange, portals, defi to permited type storage
Don't forget add new addresses to new permittedAddresses contract
Don't forget set latest 1incg contract
```
