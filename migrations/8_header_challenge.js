const HeaderChallenge = artifacts.require('HeaderChallenge');

module.exports = function(deployer) {
  deployer.deploy(HeaderChallenge);
};
