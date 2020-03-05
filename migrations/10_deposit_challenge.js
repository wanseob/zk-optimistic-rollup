const DepositChallenge = artifacts.require('DepositChallenge');

module.exports = function(deployer) {
  deployer.deploy(DepositChallenge);
};
