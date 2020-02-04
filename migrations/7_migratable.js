const Migratable = artifacts.require('Migratable');

module.exports = function(deployer) {
  deployer.deploy(Migratable);
};
