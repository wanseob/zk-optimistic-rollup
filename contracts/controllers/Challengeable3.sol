pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { Challengeable } from "./Challengeable.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { SMT256 } from "../../node_modules/smt-rollup/contracts/SMT.sol";
import {
    Block,
    TxType,
    Challenge,
    Migration,
    Withdrawal,
    L2Tx,
    Types
} from "../libraries/Types.sol";

contract Challengeable3 is Challengeable {
    using SMT256 for SMT256.OPRU;
    using Types for *;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

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
        if (txType == TxType.Withdrawal) {
            validate = _challengeResultOfWithdrawal;
        } else if (txType == TxType.Migration) {
            validate = _challengeResultOfMigration;
        } else {
            validate = _challengeResultOfL2Tx;
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
            L2Tx memory l2Tx = submission.body.l2Txs[txIndex];
            ref = l2Tx.inclusionRefs[refIndex];
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

    function _challengeResultOfL2Tx(
        Block memory submission,
        uint txIndex
    )
        internal
        view
        returns (Challenge memory)
    {
        L2Tx memory l2Tx = submission.body.l2Txs[txIndex];

        /// Slash if the length of the array is not same with the metadata
        if (
            l2Tx.numberOfInputs != l2Tx.inclusionRefs.length ||
            l2Tx.numberOfInputs != l2Tx.nullifiers.length
        ) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "Invalid tx body"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            TxType(l2Tx.txType),
            l2Tx.numberOfInputs,
            l2Tx.numberOfOutputs
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
        uint[] memory inputs = new uint[](1 + 2*l2Tx.numberOfInputs + l2Tx.numberOfOutputs);
        uint index = 0;
        inputs[index++] = uint(l2Tx.fee);
        for (uint i = 0; i < l2Tx.numberOfInputs; i++) {
            inputs[index++] = uint(l2Tx.inclusionRefs[i]);
        }
        for (uint i = 0; i < l2Tx.numberOfInputs; i++) {
            inputs[index++] = uint(l2Tx.nullifiers[i]);
        }
        for (uint i = 0; i < l2Tx.numberOfOutputs; i++) {
            inputs[index++] = uint(l2Tx.outputs[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(l2Tx.proof);
        if (!vk.zkSNARKs(inputs, proof)) {
            return Challenge(
                true,
                submission.id,
                submission.header.proposer,
                "SNARKs failed"
            );
        }
        /// Passed all tests. It's a valid transaction. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "Valid l2Tx"
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
                "Invalid tx body"
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
        uint[] memory inputs = new uint[](4 + 2 * withdrawal.numberOfInputs);
        uint index = 0;
        inputs[index++] = uint(withdrawal.amount);
        inputs[index++] = uint(withdrawal.fee);
        inputs[index++] = uint(withdrawal.to);
        inputs[index++] = uint(withdrawal.nft);
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
                "SNARKs failed"
            );
        }
        /// Passed all tests. It's a valid withdrawal. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "Valid withdrawal"
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
                "Invalid tx body"
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
                "SNARKs failed"
            );
        }
        /// Passed all tests. It's a valid migration. Challenge is not accepted
        return Challenge(
            false,
            submission.id,
            submission.header.proposer,
            "Valid migration"
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
            usedNullifier = submission.body.l2Txs[txIndex].nullifiers[nullifierIndex];
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
        for (uint i = 0; i < submission.body.l2Txs.length; i++) {
            L2Tx memory l2Tx = submission.body.l2Txs[i];
            for (uint j = 0; j < l2Tx.nullifiers.length; j++) {
                /// Found matched nullifier
                if (l2Tx.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        for (uint i = 0; i < submission.body.withdrawals.length; i++) {
            Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for (uint j = 0; j < withdrawal.nullifiers.length; j++) {
                /// Found matched nullifier
                if (withdrawal.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        for (uint i = 0; i < submission.body.migrations.length; i++) {
            Migration memory migration = submission.body.migrations[i];
            for (uint j = 0; j < migration.nullifiers.length; j++) {
                /// Found matched nullifier
                if (migration.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        return Challenge(
            count >= 2,
            submission.id,
            submission.header.proposer,
            "Duplicated nullifier"
        );
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
}
