pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { Challengeable } from "./Challengeable.sol";
import { SplitRollUp } from "../../node_modules/merkle-tree-rollup/contracts/library/Types.sol";
import { SubTreeRollUpLib } from "../../node_modules/merkle-tree-rollup/contracts/library/SubTreeRollUpLib.sol";
import { RollUpLib } from "../../node_modules/merkle-tree-rollup/contracts/library/RollUpLib.sol";
import { SMT256 } from "../../node_modules/smt-rollup/contracts/SMT.sol";
import {
    Block,
    Challenge,
    Transfer,
    Withdrawal,
    Migration,
    Types
} from "../libraries/Types.sol";

contract Challengeable1 is Challengeable {
    using SubTreeRollUpLib for SplitRollUp;
    using Types for *;
    using SMT256 for SMT256.OPRU;

    function challengeUTXORollUp(
        uint utxoRollUpId,
        uint[] calldata deposits,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(2);
        Challenge memory result = _challengeResultOfUTXORollUp(submission, utxoRollUpId, deposits);
        _execute(result);
    }

    function challengeNullifierRollUp(
        uint nullifierRollUpId,
        uint numOfNullifiers,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(2);
        Challenge memory result = _challengeResultOfNullifierRollUp(
            submission,
            nullifierRollUpId,
            numOfNullifiers
        );
        _execute(result);
    }

    function challengeWithdrawalRollUp(
        uint withdrawalRollUpId,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(1);
        Challenge memory result = _challengeResultOfWithdrawalRollUp(submission, withdrawalRollUpId);
        _execute(result);
    }

    /** Computes challenge here */
    function _challengeResultOfUTXORollUp(
        Block memory submission,
        uint utxoRollUpId,
        uint[] memory deposits
    )
        internal
        view
        returns (Challenge memory)
    {
        require(deposits.root() == submission.header.depositRoot, "invalid deposit data");

        /// Get total outputs
        uint numOfItems = 0;
        numOfItems += deposits.length;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Transfer memory transfer = submission.body.transfers[i];
            numOfItems += transfer.outputs.length;
        }

        /// Assign a new array
        uint[] memory outputs = new uint[](numOfItems);
        /// Get outputs to append
        uint index = 0;
        for (uint i = 0; i < deposits.length; i++) {
            outputs[index++] = deposits[i];
        }
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Transfer memory transfer = submission.body.transfers[i];
            for (uint j = 0; j < transfer.outputs.length; j++) {
                outputs[index++] = uint(transfer.outputs[j]);
            }
        }

        /// Start a new tree if there's no room to add the new outputs
        uint startingIndex;
        uint startingRoot;
        if (submission.header.prevUTXOIndex + numOfItems < POOL_SIZE) {
            /// it uses the latest tree
            startingIndex = submission.header.prevUTXOIndex;
            startingRoot = submission.header.prevUTXORoot;
        } else {
            /// start a new tree
            startingIndex = 0;
            startingRoot = 0;
        }
        /// Submitted invalid next output index
        if (submission.header.nextUTXOIndex != (startingIndex + numOfItems)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "UTXO tree flushed"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        SplitRollUp memory rollUpProof = Layer2.proof.ofUTXORollUp[utxoRollUpId];
        bool isValidRollUp = rollUpProof.verify(
            SubTreeRollUpLib.newSubTreeOPRU(
                uint(startingRoot),
                startingIndex,
                uint(submission.header.nextUTXORoot),
                SUB_TREE_DEPTH,
                outputs
            )
        );

        return Challenge(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "UTXO roll up"
        );
    }

    /// Possibility to cost a lot of failure gases because of the 'already slashed' submissions
    function _challengeResultOfNullifierRollUp(
        Block memory submission,
        uint nullifierRollUpId,
        uint numOfNullifiers
    )
        internal
        view
        returns (Challenge memory)
    {
        /// Assign a new array
        bytes32[] memory nullifiers = new bytes32[](numOfNullifiers);
        /// Get outputs to append
        uint index = 0;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Transfer memory transfer = submission.body.transfers[i];
            for (uint j = 0; j < transfer.nullifiers.length; j++) {
                nullifiers[index++] = transfer.nullifiers[j];
            }
        }
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for (uint j = 0; j < withdrawal.nullifiers.length; j++) {
                nullifiers[index++] = withdrawal.nullifiers[j];
            }
        }
        for (uint i = 0; i < submission.body.migrations.length; i++) {
            Migration memory migration = submission.body.migrations[i];
            for (uint j = 0; j < migration.nullifiers.length; j++) {
                nullifiers[index++] = migration.nullifiers[j];
            }
        }

        require(index == numOfNullifiers, "Invalid length of the nullifiers");

        /// Get rolled up root
        SMT256.OPRU memory proof = Layer2.proof.ofNullifierRollUp[nullifierRollUpId];
        bool isValidRollUp = proof.verify(
            submission.header.prevNullifierRoot,
            submission.header.nextNullifierRoot,
            RollUpLib.merge(bytes32(0), nullifiers)
        );

        return Challenge(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "Nullifier roll up"
        );
    }

    function _challengeResultOfWithdrawalRollUp(Block memory submission, uint withdrawalRollUpId)
        internal
        view
        returns (Challenge memory)
    {
        /// Get total outputs
        uint numOfWithdrawals = submission.body.withdrawals.length;
        /// Assign a new array
        bytes32[] memory withdrawalLeaves = new bytes32[](numOfWithdrawals);
        /// Get withdrawals to append
        for (uint i = 0; i < numOfWithdrawals; i++) {
            withdrawalLeaves[i] = keccak256(
                abi.encodePacked(
                    submission.body.withdrawals[i].amount,
                    submission.body.withdrawals[i].to,
                    keccak256(abi.encodePacked(submission.body.withdrawals[i].proof))
                )
            );
        }
        /// Start a new tree if there's no room to add the new withdrawals
        uint startingIndex;
        bytes32 startingRoot;
        if (submission.header.prevWithdrawalIndex + numOfWithdrawals < POOL_SIZE) {
            /// it uses the latest tree
            startingIndex = submission.header.prevWithdrawalIndex;
            startingRoot = submission.header.prevWithdrawalRoot;
        } else {
            /// start a new tree
            startingIndex = 0;
            startingRoot = 0;
        }
        /// Submitted invalid index of the next withdrawal tree
        if (submission.header.nextWithdrawalIndex != (startingIndex + numOfWithdrawals)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Withdrawal tree flushed"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        SplitRollUp memory proof = Layer2.proof.ofWithdrawalRollUp[withdrawalRollUpId];
        uint[] memory uintLeaves;
        assembly {
            uintLeaves := withdrawalLeaves
        }
        bool isValidRollUp = proof.verify(
            SubTreeRollUpLib.newSubTreeOPRU(
                uint(startingRoot),
                startingIndex,
                uint(submission.header.nextWithdrawalRoot),
                SUB_TREE_DEPTH,
                uintLeaves
            )
        );

        return Challenge(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "Withdrawal roll up"
        );
    }
}
