const TxChallenge = artifacts.require('TxChallenge');

module.exports = function(deployer) {
  deployer.deploy(TxChallenge);
};
