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
      // Setup proxy
      let registration = {
        challenge: wizard.registerChallengeContract,
        ui: wizard.registerUIContract,
        rollup: wizard.registerRollUpContract,
        migrate: wizard.registerMigrateContract
      };
      Object.keys(registration).forEach(async key => {
        let instance = instances[key];
        let sigs = instance.abi.filter(func => func.stateMutability !== 'view').map(func => func.signature);
        await registration[key](instance.address, sigs);
      });
      // Setup erc20
      await wizard.registerERC20(instances.erc20.address);
      // Setup zkSNARKs
      // await wizard.registerVk(...)
      // Setup migrations
      // await wizard.allowMigrants(...)
      // Complete setup
      await wizard.completeSetup();
    });
};
