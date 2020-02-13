const MiMC = artifacts.require('MiMC');
const TestERC20 = artifacts.require('TestERC20');
const UserInteractable = artifacts.require('UserInteractable');
const RollUpable = artifacts.require('RollUpable');
const Challengeable1 = artifacts.require('Challengeable1');
const Challengeable2 = artifacts.require('Challengeable2');
const Challengeable3 = artifacts.require('Challengeable3');
const Migratable = artifacts.require('Migratable');
const ZkOPRU = artifacts.require('ZkOptimisticRollUp');
const ISetupWizard = artifacts.require('ISetupWizard');

let instances = {};

module.exports = function(deployer, _, accounts) {
  deployer
    .then(function() {
      return TestERC20.deployed();
    })
    .then(function(erc20) {
      instances.erc20 = erc20;
      return UserInteractable.deployed();
    })
    .then(function(ui) {
      instances.ui = ui;
      return RollUpable.deployed();
    })
    .then(function(rollUp) {
      instances.rollup = rollUp;
      return Challengeable1.deployed();
    })
    .then(function(challenge1) {
      instances.challenge1 = challenge1;
      return Challengeable2.deployed();
    })
    .then(function(challenge2) {
      instances.challenge2 = challenge2;
      return Challengeable3.deployed();
    })
    .then(function(challenge3) {
      instances.challenge3 = challenge3;
      return Migratable.deployed();
    })
    .then(function(migrate) {
      instances.migrate = migrate;
      return ZkOPRU.deployed();
    })
    .then(function(coordinate) {
      return ISetupWizard.at(coordinate.address);
    })
    .then(async function(wizard) {
      // Connect ERC20 asset
      await wizard.registerERC20(instances.erc20.address);
      // Setup proxy
      await wizard.makeUserInteractable(instances.ui.address);
      await wizard.makeRollUpable(instances.rollup.address);
      await wizard.makeChallengeable(instances.challenge1.address, instances.challenge2.address, instances.challenge3.address);
      await wizard.makeMigratable(instances.migrate.address);
      // Setup zkSNARKs
      // await wizard.registerVk(...)
      // Setup migrations
      // await wizard.allowMigrants(...)
      // Complete setup
      await wizard.completeSetup();
    });
};
