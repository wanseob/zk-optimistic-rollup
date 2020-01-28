pragma solidity >= 0.6.0;

import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { Layer1 } from "../libraries/Layer1.sol";
import { Layer2 } from "../libraries/Layer2.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";

contract UserInteractable is ZkOptimisticRollUpStore {
    using Layer1 for address;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

    /**
     * End-user interaction functions
     * - deposit
     * - cancelDeposit
     * - withdraw
     */
    function deposit(bytes32 note, uint amount, uint fee, uint[2] memory pubKey) public payable {
        require(note != bytes32(0), "Note hash can not be zero");
        /// TODO: Verify note validity
        /// get fund
        l1Asset.toLayer2(address(this), amount + fee);
        /// Record deposit
        l2Chain.pendingDeposits[note] = Layer2.Deposit(note, amount, fee);
    }

    function cancelDeposit(
        bytes32 note,
        uint[2] memory pubKey,
        uint[2] memory R,
        uint s
    ) public {
        /// TODO: Verify note validity
        /// TODO: signature of the note ownership
        /// find deposit and try to cancel
        /// send the fee back
        require(l2Chain.pendingDeposits[note].note != bytes32(0), "Does not exist or already committed");
        uint amount = l2Chain.pendingDeposits[note].fee + l2Chain.pendingDeposits[note].amount;
        l1Asset.withdrawFromLayer2(msg.sender, amount);
        delete l2Chain.pendingDeposits[note];
    }
}
