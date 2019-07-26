const Hydro = artifacts.require('Hydro');
const PriceOracle = artifacts.require('./helper/PriceOracle');
const HydroToken = artifacts.require('HydroToken');
const FeedPriceOracle = artifacts.require('FeedPriceOracle');
const TestToken = artifacts.require('TestToken');
const ConstPriceOracle = artifacts.require('ConstPriceOracle');
const DefaultInterestModel = artifacts.require('DefaultInterestModel');

const Auctions = artifacts.require('Auctions');
const BatchActions = artifacts.require('BatchActions');

const OperationsComponent = artifacts.require('OperationsComponent');

module.exports = async (deployer, network) => {
    let hotAddress;

    const deployHydroMainContract = async hotAddress => {
        await deployer.deploy(BatchActions);
        await deployer.deploy(Auctions);
        await deployer.deploy(OperationsComponent);

        await deployer.link(BatchActions, Hydro);
        await deployer.link(OperationsComponent, Hydro);
        await deployer.link(Auctions, Hydro);

        await deployer.deploy(Hydro, hotAddress);
    };

    if (network == 'production') {
        hotAddress = '0x9af839687f6c94542ac5ece2e317daae355493a1';
        await deployHydroMainContract(hotAddress);
        await deployer.deploy(DefaultInterestModel);
    } else if (network == 'kovan') {
        hotAddress = '0x16c4f3DcFcC23fAA9fc8e3E849BDf966953beE91';

        await deployHydroMainContract(hotAddress);
        await deployer.deploy(DefaultInterestModel);

        // use Price Oracle for test
        await deployer.deploy(PriceOracle);
    } else if (network == 'ropsten') {
        await deployer.deploy(HydroToken);
        hot = await HydroToken.deployed();

        await deployer.deploy(TestToken, 'Test Ethereum', 'tETH', 18);

        await deployHydroMainContract(hot.address);
        await deployer.deploy(DefaultInterestModel);

        await deployer.deploy(FeedPriceOracle);
        await deployer.deploy(ConstPriceOracle);
    }
};
