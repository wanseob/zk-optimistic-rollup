pragma solidity >= 0.6.0;

import { Challengeable } from "./zk-opru-base/Challengeable.sol";
import { Coordinatable } from "./zk-opru-base/Coordinatable.sol";
import { SetupWizard } from "./zk-opru-base/SetupWizard.sol";
import { UserInteractable } from "./zk-opru-base/UserInteractable.sol";


contract OptimisticSNARKsRollUp is UserInteractable, Coordinatable, Challengeable, SetupWizard {
    constructor(
        address _erc20,
        address _setupWizard
    ) public SetupWizard(_erc20, _setupWizard){
    }
}
