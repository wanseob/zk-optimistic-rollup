const TestERC20 = artifacts.require('TestERC20');

module.exports = function(deployer) {
  deployer.deploy(TestERC20, web3.utils.toWei('1000000000'));
};
