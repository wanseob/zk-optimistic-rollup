const MiMC = artifacts.require('MiMC');
const ZkOPRU = artifacts.require('ZkOptimisticRollUp');

module.exports = function(deployer, _, accounts) {
  deployer.link(MiMC, ZkOPRU);
  deployer.deploy(ZkOPRU, accounts[0]);
};
