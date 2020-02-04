const Challengeable = artifacts.require('Challengeable');

module.exports = function(deployer) {
  deployer.deploy(Challengeable);
};
