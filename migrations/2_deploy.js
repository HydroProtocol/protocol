const Hydro = artifacts.require('Hydro');
const PriceOracle = artifacts.require('PriceOracle');
const HydroToken = artifacts.require('HydroToken');
const Auctions = artifacts.require('Auctions');
const OperationsLib = artifacts.require('OperationsLib');
const DefaultInterestModel = artifacts.require('DefaultInterestModel');
const LendingPoolTokenFactory = artifacts.require('LendingPoolTokenFactory');
const ExternalFunctions = artifacts.require('ExternalFunctions');
module.exports = async (deployer, network) => {
    let hotAddress;

    if (network == 'production') {
        hotAddress = '0x9af839687f6c94542ac5ece2e317daae355493a1';
    } else {
        await deployer.deploy(HydroToken);
        hot = await HydroToken.deployed();
        hotAddress = hot.address;
    }

    await deployer.deploy(LendingPoolTokenFactory);
    await deployer.link(LendingPoolTokenFactory, OperationsLib);

    await deployer.deploy(Auctions);
    await deployer.deploy(OperationsLib);

    await deployer.link(OperationsLib, Hydro);
    await deployer.link(Auctions, Hydro);

    await deployer.deploy(DefaultInterestModel);
    await deployer.deploy(Hydro, hotAddress);
    await deployer.deploy(PriceOracle);
};
