const Hydro = artifacts.require('Hydro');
const PriceOracle = artifacts.require('./helper/PriceOracle');
const HydroToken = artifacts.require('HydroToken');
const DefaultInterestModel = artifacts.require('DefaultInterestModel');

const Auctions = artifacts.require('Auctions');
const BatchActions = artifacts.require('BatchActions');
const OperationsLib = artifacts.require('OperationsLib');

module.exports = async (deployer, network) => {
    let hotAddress;

    if (network == 'production') {
        hotAddress = '0x9af839687f6c94542ac5ece2e317daae355493a1';
    } else {
        await deployer.deploy(HydroToken);
        hot = await HydroToken.deployed();
        hotAddress = hot.address;
    }

    await deployer.deploy(BatchActions);
    await deployer.deploy(Auctions);
    await deployer.deploy(OperationsLib);

    await deployer.link(BatchActions, Hydro);
    await deployer.link(OperationsLib, Hydro);
    await deployer.link(Auctions, Hydro);

    await deployer.deploy(DefaultInterestModel);
    await deployer.deploy(Hydro, hotAddress);
    await deployer.deploy(PriceOracle);
};
