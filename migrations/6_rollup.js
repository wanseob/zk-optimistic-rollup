const Poseidon = artifacts.require('Poseidon');
const RollUpable = artifacts.require('RollUpable');

module.exports = function(deployer) {
  deployer.link(Poseidon, RollUpable);
  deployer.deploy(RollUpable);
};
