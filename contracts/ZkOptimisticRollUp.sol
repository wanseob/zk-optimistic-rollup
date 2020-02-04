pragma solidity >= 0.6.0;

import { SetupWizard } from "./zk-opru-base/SetupWizard.sol";


contract ZkOptimisticRollUp is SetupWizard {
    constructor(
        address _setupWizard
    ) public SetupWizard(_setupWizard) {

    }
}
