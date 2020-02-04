const MiMC = artifacts.require('MiMC');
const TestERC20 = artifacts.require('TestERC20');
const UserInteractable = artifacts.require('UserInteractable');
const RollUpable = artifacts.require('RollUpable');
const Challengeable = artifacts.require('Challengeable');
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
      return Challengeable.deployed();
    })
    .then(function(challenge) {
      instances.challenge = challenge;
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
      await wizard.connectUserInteractable(instances.ui.address);
      await wizard.connectRollUpable(instances.rollup.address);
      await wizard.connectChallengeable(instances.challenge.address);
      await wizard.connectMigratable(instances.migrate.address);
      // Setup zkSNARKs
      // await wizard.registerVk(...)
      // Setup migrations
      // await wizard.allowMigrants(...)
      // Complete setup
      await wizard.completeSetup();
    });
};
