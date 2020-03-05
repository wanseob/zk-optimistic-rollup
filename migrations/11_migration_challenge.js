const MigrationChallenge = artifacts.require('MigrationChallenge');

module.exports = function(deployer) {
  deployer.deploy(MigrationChallenge);
};
