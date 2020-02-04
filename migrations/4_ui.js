const MiMC = artifacts.require('MiMC');
const UserInteractable = artifacts.require('UserInteractable');

module.exports = function(deployer) {
  deployer.link(MiMC, UserInteractable);
  deployer.deploy(UserInteractable);
};
