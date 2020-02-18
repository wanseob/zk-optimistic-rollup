const Poseidon = artifacts.require('Poseidon');
const UserInteractable = artifacts.require('UserInteractable');

module.exports = function(deployer) {
  deployer.link(Poseidon, UserInteractable);
  deployer.deploy(UserInteractable);
};
