pragma solidity >= 0.6.0;

import { Hasher , OPRU, ExtendedOPRU } from "../../../node_modules/merkle-tree-rollup/contracts/library/Types.sol";
import { OPRULib } from "../../../node_modules/merkle-tree-rollup/contracts/library/OPRULib.sol";
import { SMT256 } from "../../../node_modules/smt-rollup/contracts/SMT.sol";
import { Layer2 } from "./../Layer2.sol";
import { SNARKsVerifier } from "../../libraries/SNARKs.sol";
import { Hash } from "../../libraries/Hash.sol";
import {
    TxType,
    Proposal,
    Challenge,
    Block,
    MassDeposit,
    MassMigration,
    Migration,
    Withdrawal,
    Transfer,
    Proposer,
    Proposal,
    Types
} from "../../libraries/Types.sol";

contract Challengeable is Layer2 {
    using OPRULib for *;
    using Types for *;
    using SMT256 for SMT256.OPRU;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

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

    function challengeDepositRoot(
        uint[] calldata deposits,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(1);
        Challenge memory result = _challengeResultOfDepositRoot(submission, deposits);
        _execute(result);
    }

    function challengeTransferRoot(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfTransferRoot(submission);
        _execute(result);
    }

    function challengeWithdrawalRoot(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfWithdrawalRoot(submission);
        _execute(result);
    }

    function challengeMigrationRoot(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfMigrationRoot(submission);
        _execute(result);
    }

    function challengeTotalFee(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfTotalFee(submission);
        _execute(result);
    }

    function challengeInclusion(
        TxType txType,
        uint txIndex,
        uint refIndex,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(3);
        Challenge memory result = _challengeResultOfInclusion(
            submission,
            txType,
            txIndex,
            refIndex
        );
        _execute(result);
    }

    function challengeTransaction(TxType txType, uint index, bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(2);
        function (Block memory, uint) internal view returns(Challenge memory) validate;
        if (txType == TxType.Transfer) {
            validate = _challengeResultOfTransfer;
        } else if (txType == TxType.Withdrawal) {
            validate = _challengeResultOfWithdrawal;
        } else if (txType == TxType.Migration) {
            validate = _challengeResultOfMigration;
        }
        Challenge memory result = validate(submission, index);
        _execute(result);
    }

    function challengeUsedNullifier(
        TxType txType,
        uint txIndex,
        uint nullifierIndex,
        bytes32[256] calldata sibling,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(4);
        Challenge memory result = _challengeResultOfUsedNullifier(
            submission,
            txType,
            txIndex,
            nullifierIndex,
            sibling
        );
        _execute(result);
    }

    function challengeDuplicatedNullifier(bytes32 nullifier, bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(1);
        Challenge memory result = _challengeResultOfDuplicatedNullifier(submission, nullifier);
        _execute(result);
    }

    function isValidRef(bytes32 l2BlockHash, uint256 ref) public view returns (bool) {
        if (Layer2.chain.finalizedUTXOs[ref]) {
            return true;
        }
        bytes32 parentBlock = l2BlockHash;
        for (uint i = 0; i < REF_DEPTH; i++) {
            parentBlock = Layer2.chain.parentOf[parentBlock];
            if (Layer2.chain.utxoRootOf[parentBlock] == ref) {
                return true;
            }
        }
        return false;
    }

    /** Internal functions to help reusable clean code */
    function _getVerifyingKey(
        TxType txType,
        uint8 numberOfInputs,
        uint8 numberOfOutputs
    ) internal view returns (SNARKsVerifier.VerifyingKey memory) {
        return vks[Types.getSNARKsSignature(txType, numberOfInputs, numberOfOutputs)];
    }

    function _exist(SNARKsVerifier.VerifyingKey memory vk) internal pure returns (bool) {
        if (vk.alfa1.X != 0) {
            return true;
        } else {
            return false;
        }
    }

    function _checkChallengeCondition(Proposal storage proposal) internal view {
        /// Check the optimistic roll up is in the challenge period
        require(proposal.challengeDue > block.number, "You missed the challenge period");
        /// Check it is already slashed
        require(!proposal.slashed, "Already slashed");
        /// Check the optimistic rollup exists
        require(proposal.headerHash != bytes32(0), "Not an existing rollup");
    }

    function _forfeitAndReward(address proposerAddr, address challenger) internal {
        Proposer storage proposer = Layer2.chain.proposers[proposerAddr];
        /// Reward
        uint challengeReward = proposer.stake * 2 / 3;
        payable(challenger).transfer(challengeReward);
        /// Forfeit
        proposer.stake = 0;
        proposer.reward = 0;
        /// Delete proposer
        delete Layer2.chain.proposers[proposerAddr];
    }

    function _execute(Challenge memory result) internal {
        require(result.slash, result.message);

        Proposal storage proposal = Layer2.chain.proposals[result.proposalId];
        /// Check basic challenge conditions
        _checkChallengeCondition(proposal);
        /// Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        proposal.slashed = true; /// Record it as slashed;
        _forfeitAndReward(result.proposer, msg.sender);
        /// TODO log message
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
        require(deposits.root() == submission.header.depositRoot, "Submitted invalid deposit data");

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
                "This proposal lets the UTXO tree flush"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        ExtendedOPRU memory proof = Layer2.proof.ofUTXO[utxoRollUpId];
        bool isValidRollUp = proof.opru.verify(
            uint(startingRoot),
            startingIndex,
            uint(submission.header.nextUTXORoot),
            bytes32(0).mergeLeaves(outputs)
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

        require(index == numOfNullifiers, "Submitted invalid length for the array nullifiers");

        /// Get rolled up root
        SMT256.OPRU memory proof = Layer2.proof.ofNullifier[nullifierRollUpId];
        bool isValidRollUp = proof.verify(
            submission.header.prevNullifierRoot,
            submission.header.nextNullifierRoot,
            bytes32(0).mergeLeaves(nullifiers)
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
                "This proposal lets the UTXO tree flush"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        OPRU memory proof = Layer2.proof.ofWithdrawal[withdrawalRollUpId];
        bool isValidRollUp = proof.verify(
            uint(startingRoot),
            startingIndex,
            uint(submission.header.nextWithdrawalRoot),
            bytes32(0).mergeLeaves(withdrawalLeaves)
        );

        return Challenge(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "Withdrawal roll up"
        );
    }

    function _challengeResultOfDepositRoot(
        Block memory submission,
        uint[] memory deposits
    )
        internal
        view
        returns (Challenge memory)
    {
        uint index = 0;
        bytes32 merged;
        for (uint i = 0; i < submission.body.depositIds.length; i++) {
            merged = bytes32(0);
            MassDeposit storage depositsToAdd = Layer2.chain.depositQueue[submission.body.depositIds[i]];
            if (!depositsToAdd.committed) {
                return Challenge(
                    true,
                    submission.id,
                    submission.header.proposer,
                    "This deposit queue is not committed"
                );
            }
            for (uint j = 0; j < depositsToAdd.length; j++) {
                merged = keccak256(abi.encodePacked(merged, deposits[index]));
                index++;
            }
            require(merged == depositsToAdd.merged, "Submitted invalid set of deposits");
        }
        require(index == deposits.length, "Submitted extra deposits");
        return Challenge(
            submission.header.depositRoot != deposits.root(),
            submission.id,
            submission.header.proposer,
            "Deposit root validation"
        );
    }

    function _challengeResultOfTransferRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.transferRoot != submission.body.transfers.root(),
            submission.id,
            submission.header.proposer,
            "Transfer root validation"
        );
    }

    function _challengeResultOfWithdrawalRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.withdrawalRoot != submission.body.withdrawals.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfMigrationRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.migrationRoot != submission.body.migrations.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfTotalFee(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        uint totalFee = 0;
        for (uint i = 0; i < submission.body.transfers.length; i ++) {
            totalFee += submission.body.transfers[i].fee;
        }
        for (uint i = 0; i < submission.body.withdrawals.length; i ++) {
            totalFee += submission.body.withdrawals[i].fee;
        }
        for (uint i = 0; i < submission.body.migrations.length; i ++) {
            totalFee += submission.body.migrations[i].fee;
        }
        return Challenge(
            totalFee != submission.header.fee,
            submission.id,
            submission.header.proposer,
            "Total fee validation"
        );
    }

    function _challengeResultOfInclusion(
        Block memory submission,
        TxType txType,
        uint txIndex,
        uint refIndex
    )
        internal
        view
        returns (Challenge memory)
    {
        uint ref;
        if (txType == TxType.Transfer) {
            Transfer memory transfer = submission.body.transfers[txIndex];
            ref = transfer.inclusionRefs[refIndex];
        } else if (txType == TxType.Withdrawal) {
            Withdrawal memory withdrawal = submission.body.withdrawals[txIndex];
            ref = withdrawal.inclusionRefs[refIndex];
        } else if (txType == TxType.Migration) {
            Migration memory migration = submission.body.migrations[txIndex];
            ref = migration.inclusionRefs[refIndex];
        }

        return Challenge(
            !isValidRef(submission.header.hash(), ref),
            submission.id,
            submission.header.proposer,
            "Inclusion reference validation"
        );
    }

    function _challengeResultOfTransfer(
        Block memory submission,
        uint txIndex
    )
        internal
        view
        returns (Challenge memory)
    {
        Transfer memory transfer = submission.body.transfers[txIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            transfer.numberOfInputs != transfer.inclusionRefs.length ||
            transfer.numberOfInputs != transfer.nullifiers.length
        ) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            TxType.Transfer,
            transfer.numberOfInputs,
            transfer.numberOfOutputs
        );
        if (!_exist(vk)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Unsupported tx type"
            );
        }
        /// Slash if its zk SNARKs verification returns false
        uint[] memory inputs = new uint[](1 + 2*transfer.numberOfInputs + transfer.numberOfOutputs);
        uint index = 0;
        inputs[index++] = uint(transfer.fee);
        for (uint i = 0; i < transfer.numberOfInputs; i++) {
            inputs[index++] = uint(transfer.inclusionRefs[i]);
        }
        for (uint i = 0; i < transfer.numberOfInputs; i++) {
            inputs[index++] = uint(transfer.nullifiers[i]);
        }
        for (uint i = 0; i < transfer.numberOfOutputs; i++) {
            inputs[index++] = uint(transfer.outputs[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(transfer.proof);
        if (!vk.zkSNARKs(inputs, proof)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid transaction. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid transfer"
        );
    }

    function _challengeResultOfWithdrawal(
        Block memory submission,
        uint withdrawalIndex
    )
        internal
        view
        returns (Challenge memory)
    {
        Withdrawal memory withdrawal = submission.body.withdrawals[withdrawalIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            withdrawal.numberOfInputs != withdrawal.inclusionRefs.length ||
            withdrawal.numberOfInputs != withdrawal.nullifiers.length
        ) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            TxType.Withdrawal,
            withdrawal.numberOfInputs,
            0
        );
        if (!_exist(vk)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Unsupported tx type"
            );
        }
        /// Slash if its zk SNARKs verification returns false
        uint[] memory inputs = new uint[](3 + 2 * withdrawal.numberOfInputs);
        uint index = 0;
        inputs[index++] = uint(withdrawal.amount);
        inputs[index++] = uint(withdrawal.fee);
        inputs[index++] = uint(withdrawal.to);
        for (uint i = 0; i < withdrawal.numberOfInputs; i++) {
            inputs[index++] = uint(withdrawal.inclusionRefs[i]);
        }
        for (uint i = 0; i < withdrawal.numberOfInputs; i++) {
            inputs[index++] = uint(withdrawal.nullifiers[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(withdrawal.proof);
        if (!vk.zkSNARKs(inputs, proof)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid withdrawal. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid withdrawal"
        );
    }

    function _challengeResultOfMigration(
        Block memory submission,
        uint migrationIndex
    )
        internal
        view
        returns (Challenge memory)
    {
        Migration memory migration = submission.body.migrations[migrationIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            migration.numberOfInputs != migration.inclusionRefs.length ||
            migration.numberOfInputs != migration.nullifiers.length
        ) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            TxType.Migration,
            migration.numberOfInputs,
            0
        );
        if (!_exist(vk)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Unsupported tx type"
            );
        }
        /// Slash if its zk SNARKs verification returns false
        uint[] memory inputs = new uint[](5 + 2 * migration.numberOfInputs);
        uint index = 0;
        inputs[index++] = uint(migration.leaf);
        inputs[index++] = uint(migration.destination);
        inputs[index++] = uint(migration.amount);
        inputs[index++] = uint(migration.fee);
        inputs[index++] = uint(migration.migrationFee);
        for (uint i = 0; i < migration.numberOfInputs; i++) {
            inputs[index++] = uint(migration.inclusionRefs[i]);
        }
        for (uint i = 0; i < migration.numberOfInputs; i++) {
            inputs[index++] = uint(migration.nullifiers[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(migration.proof);
        if (!vk.zkSNARKs(inputs, proof)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid migration. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid migration"
        );
    }

    function _challengeResultOfUsedNullifier(
        Block memory submission,
        TxType txType,
        uint txIndex,
        uint nullifierIndex,
        bytes32[256] memory sibling
    )
        internal
        pure
        returns (Challenge memory)
    {
        bytes32 usedNullifier;
        if (txType == TxType.Transfer) {
            usedNullifier = submission.body.transfers[txIndex].nullifiers[nullifierIndex];
        } else if (txType == TxType.Withdrawal) {
            usedNullifier = submission.body.withdrawals[txIndex].nullifiers[nullifierIndex];
        } else if (txType == TxType.Migration) {
            usedNullifier = submission.body.migrations[txIndex].nullifiers[nullifierIndex];
        }
        bytes32[] memory nullifiers = new bytes32[](1);
        bytes32[256][] memory siblings = new bytes32[256][](1);
        nullifiers[0] = usedNullifier;
        siblings[0] = sibling;
        bytes32 updatedRoot = SMT256.rollUp(
            submission.header.prevNullifierRoot,
            nullifiers,
            siblings
        );
        return Challenge(
            updatedRoot == submission.header.prevNullifierRoot,
            submission.id,
            submission.header.proposer,
            "Double spending validation"
        );
    }

    function _challengeResultOfDuplicatedNullifier(
        Block memory submission,
        bytes32 nullifier
    )
        internal
        pure
        returns (Challenge memory)
    {

        uint count = 0;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Transfer memory transfer = submission.body.transfers[i];
            for (uint j = 0; j < transfer.nullifiers.length; j++) {
                /// Found matched nullifier
                if (transfer.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for (uint j = 0; j < withdrawal.nullifiers.length; j++) {
                /// Found matched nullifier
                if (withdrawal.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        return Challenge(
            count >= 2,
            submission.id,
            submission.header.proposer,
            "Validation of duplicated usage in a block"
        );
    }
}
