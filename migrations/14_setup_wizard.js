const Poseidon = artifacts.require('Poseidon');
const TestERC20 = artifacts.require('TestERC20');
const UserInteractable = artifacts.require('UserInteractable');
const RollUpable = artifacts.require('RollUpable');
const RollUpChallenge = artifacts.require('RollUpChallenge');
const DepositChallenge = artifacts.require('DepositChallenge');
const HeaderChallenge = artifacts.require('HeaderChallenge');
const TxChallenge = artifacts.require('TxChallenge');
const MigrationChallenge = artifacts.require('MigrationChallenge');
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
      return RollUpChallenge.deployed();
    })
    .then(function(rollUpChallenge) {
      instances.rollUpChallenge = rollUpChallenge;
      return HeaderChallenge.deployed();
    })
    .then(function(headerChallenge) {
      instances.headerChallenge = headerChallenge;
      return TxChallenge.deployed();
    })
    .then(function(txChallenge) {
      instances.txChallenge = txChallenge;
      return DepositChallenge.deployed();
    })
    .then(function(depositChallenge) {
      instances.depositChallenge = depositChallenge;
      return MigrationChallenge.deployed();
    })
    .then(function(migrationChallenge) {
      instances.migrationChallenge = migrationChallenge;
      return Migratable.deployed();
    })
    .then(function(migratable) {
      instances.migratable = migratable;
      return ZkOPRU.deployed();
    })
    .then(function(coordinatable) {
      return ISetupWizard.at(coordinatable.address);
    })
    .then(async function(wizard) {
      // Setup proxy
      await wizard.makeUserInteractable(instances.ui.address);
      await wizard.makeRollUpable(instances.rollup.address);
      await wizard.makeChallengeable(
        instances.depositChallenge.address,
        instances.headerChallenge.address,
        instances.migrationChallenge.address,
        instances.rollUpChallenge.address,
        instances.txChallenge.address
      );
      await wizard.makeMigratable(instances.migratable.address);
      // Setup zkSNARKs
      // await wizard.registerVk(...)
      // Setup migrations
      // await wizard.allowMigrants(...)
      // Complete setup
      await wizard.completeSetup();
    });
};
