pragma solidity >= 0.6.0;

import { Layer2SetupWizard } from "./zk-opru-base/Layer2SetupWizard.sol";


contract ZkOptimisticRollUp is Layer2SetupWizard {
    constructor(
        address _setupWizard
    ) public Layer2SetupWizard(_setupWizard) {

    }
}
