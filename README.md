
<h1>
  <img src="./images/hydro.jpg" alt="Logo" height="50" />
  Hydro Protocol
</h1>

[![CircleCI](https://circleci.com/gh/HydroProtocol/protocol/tree/master.svg?style=svg)](https://circleci.com/gh/HydroProtocol/protocol/tree/master)
[![codecov](https://codecov.io/gh/HydroProtocol/protocol/branch/master/graph/badge.svg)](https://codecov.io/gh/HydroProtocol/protocol)

Hydro Protocol is an open-source framework for building decentralized exchanges. The apex of this framework is a set of Ethereum smart contracts which perform ERC20 token atomic swaps. It is inspired by our experience using the 0x Protocol.

The Hydro Smart Contracts are designed to serve developers looking to build decentralized exchanges without having to deal with the complexity and expense of designing, deploying, and securing their own smart contracts.

When compared to 0x protocol, there are several main advantages of Hydro Protocol:
1. No 3rd party fee token
We believe that a fee token, such as the current implementation of ZRX, creates needless friction and is a barrier to adoption.

2. Liquidity focused structuring
Smart contract level support for asymmetric fees and discounting yields an average of 2.5x more profit for liquidity Providers. This promotes more liquid markets, which is better for all users.

3. Flexibility: Market Orders, No Order Collision, Free Cancellation
By prioritizing order matching on a smart contract level, market orders are seamlessly integrated into existing liquidity, there is no order collision whatsoever, and order cancellation is always free.

### Install dependencies

```bash
npm install
```

### Build

To build out json ABI files:

```bash
npm run compile
```

### Test

```bash
npm run coverage
```
