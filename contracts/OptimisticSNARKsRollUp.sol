pragma solidity >= 0.6.0;

import { Challengeable } from "./zk-opru-base/Challengeable.sol";
import { Coordinatable } from "./zk-opru-base/Coordinatable.sol";
import { Migratable } from "./zk-opru-base/Migratable.sol";
import { SetupWizard } from "./zk-opru-base/SetupWizard.sol";
import { UserInteractable } from "./zk-opru-base/UserInteractable.sol";


contract OptimisticSNARKsRollUp is Migratable, UserInteractable, Coordinatable, Challengeable, SetupWizard {
    constructor(
        address _erc20,
        address _setupWizard
    ) public SetupWizard(_erc20, _setupWizard) {
    }
}
