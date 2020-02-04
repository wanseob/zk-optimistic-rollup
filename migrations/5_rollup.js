const MiMC = artifacts.require('MiMC');
const RollUpable = artifacts.require('RollUpable');

module.exports = function(deployer) {
  deployer.link(MiMC, RollUpable);
  deployer.deploy(RollUpable);
};
