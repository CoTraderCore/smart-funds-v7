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
Exchange and Pool Portals v7 not has incompatibility with older versions,
so frontend should support different version of portals
```


# Mainent deploy note

```
Don't forget set new pool and exchange, portals, defi to permited type storage
Don't forget add new addresses to new permittedAddresses contract
Don't forget set latest 1incg contract
```


# Addresses

```
Smart Fund registry

0xEEce063BB21E231B2b9981Ca254B19b651aDb021

https://etherscan.io/tx/0x91894a37a9e123ccf619c77f46da8b290207521fe230756aa83d8b01d9871f26


PermittedAddresses

0x9674ce5043606eCEE025240B7EF78fe76C8c75A6

https://etherscan.io/tx/0x97a0943b442ad18cb94b1a996bd08b7799ce59361ccbba2d76195188f5011c7d



MerkleTree

0x992F6c414A6DA6A7470dfB9D61eFc6639e9fbb0E

https://etherscan.io/tx/0xe91ad57fdab82bfea08d4382e8fea7f116dd237783493d4f722c86157ec46397



Tokens Type Storage

0x37ff4bc9a425F37d3Af95662c9D88A88d05f3417



DefiPortal

0xC8A2Ba3E9CE03f78551d7dE5706Cc275d4D3130f


https://etherscan.io/tx/0x435f8b6db26c09136df793573dfb8250ca84db2e5bb262e5f83059aaaf51ceec



Pool Portal

0x6F553184C04a4aD0b3551A4ff60FB73BB6E90408

https://etherscan.io/tx/0x64e01f4a64464a0f66882e78b009f7546b77a7f4cd847027793d5561116a1b15



COT Token

0x5c872500c00565505F3624AB435c222E558E9ff8



Stable Coin DAI

0x6B175474E89094C44Da98b954EedeAC495271d0F



Exchange Portal v4 (with 1inch.PROTO)

0x3e3C06d526b38F67D7a897Bba20906f36D2793A3

https://etherscan.io/tx/0x9085e8f79ece1c1c565c47b7987d3c7b7331fdaec575ca83c4d4388e9f118c27


Exchange Portal v5 (with 1inch.ETH)

0xD3B6933A448fF602711390f96E15c0B9cab5fF11

https://etherscan.io/tx/0x0e9f26544478dcbb7083d1995f28fa33c0da5e73e2204d14575af500ec2e1e30



Smart Fund ETH Factory

0x3344573A8b164D9ed32a11a5A9C6326dDB3dC298

https://etherscan.io/tx/0xfababcf7c20e93baea5c78dcf8e7fb71813b59c8378ee211dd7c57ce22042323


Smart Fund ERC20 Factory

0x6d85Dd4672AFad01a28bdfA8b4323bE910999954

https://etherscan.io/tx/0x63bb3c158edf079ab0f794a0214293a2d428062ec999d2060c86c07a2ba1d22a



Smart Fund ETH Factory LIGHT

0x666CAe17452Cf2112eF1479943099320AFD16d47

https://etherscan.io/tx/0xd2da3fb12b8240e03f2f1fb73c18570c6393b12abb673044196f76321e116685


Smart Fund ERC20 Factory LIGHT

0x2b4ba0A92CcC11E839d1928ae73b34E7aaC2C040

https://etherscan.io/tx/0xab0c542d0b468e7452dd9de5935a2c6564118a20ebba589045d3de02c8b73af6




DAOWallet

0xC9d742f23b4F10A3dA83821481D1B4ED8a596109



1INCH Proto

0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e


1INCH ETH

0x11111254369792b2Ca5d084aB5eEA397cA8fa48B



GetBancorData OLD

0x3aE392A4c6a99FcB991E208f9D74618fff513834

https://etherscan.io/tx/0xe7d6ed39c113a9e97968cfe5af5c7d7839442e52ae33847229f7cd7264e58571


GetBancorData NEW


0x9C81d0b71eC9a0161e1B4563Da73750e84889439

https://etherscan.io/tx/0x45b7a7fd48da3dd4176dd847e5a3b10af6ffea0940baac9606f1f92d161b8abf


Bancor pool parser OLD

0x759563F3A0f51A202e504BE5Ea3DeF0D3b4e6933

https://etherscan.io/tx/0x22c30ea4721444143a4c03823c878c2d749e87762da576c5721a16772f331adb


Bancor pool parser NEW

0x7ea4F5F89811F6d7BdAC24c458b5Ee1f11c90936

https://etherscan.io/tx/0x879e7e3dc265bf4e27120ddeeb0dee635785489bbf87c07f49e950dd9188d981



Kyber

0x818E6FECD516Ecc3849DAf6845e3EC868087B755



Uniswap Factory v1

0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95



Uniswap Router v2

0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D


```
