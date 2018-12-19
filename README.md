## Hydro Protocol

[![CircleCI](https://circleci.com/gh/HydroProtocol/protocol/tree/master.svg?style=svg)](https://circleci.com/gh/HydroProtocol/protocol/tree/master)
[![codecov](https://codecov.io/gh/HydroProtocol/protocol/branch/master/graph/badge.svg)](https://codecov.io/gh/HydroProtocol/protocol)


> Hydro Protocol is an open-source framework for building decentralized exchanges on Ethereum.

![](./images/hydro_small.jpg)

Hydro is designed for developers looking to build decentralized exchanges without having to deal with the complexity and expense of designing, deploying, and securing their own smart contracts.

## Features

Hydro 1.0 contains a single exchange contract called `HybridExchange.sol` with the following attributes:

* No order collision
* No possibility of front-running
* Accurate market orders
* Ability to collect fees as a percentage of the traded assets
* Allows asymmetrical maker/taker fee structure, rebates, discounts
* Multiple settlement models:
  * Wallet to wallet mode
  * Contract-deposit mode (supports ETH)
* Highly optimized gas usage

## Installation

```bash
npm install
```
To build json ABI files:

```bash
npm run compile
```

## Tests

```bash
npm run coverage
```

## Acknowledgments

Hydro is inspired by the [0x project](https://github.com/0xProject).

In addition, projects such as [IDEX](https://github.com/AuroraDAO/idex) and [Paradex](https://github.com/ParadexRelayer) motivated the decision to focus on first order support for **off-chain matching**.


## Contributing

1. Fork it (<https://github.com/hydroprotocol/protocol/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin feature/fooBar`)
5. Create a new Pull Request

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE.txt](LICENSE.txt) file for details