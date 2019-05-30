const Hydro = artifacts.require('Hydro');
const Oracle = artifacts.require('Oracle');

module.exports = async deployer => {
    await deployer.deploy(Hydro);
    await deployer.deploy(Oracle);
};
