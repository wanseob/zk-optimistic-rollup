pragma solidity >= 0.6.0;

import { Hasher , OPRU, ExtendedOPRU } from "../../node_modules/merkle-tree-rollup/contracts/library/Types.sol";
import { OPRULib } from "../../node_modules/merkle-tree-rollup/contracts/library/OPRULib.sol";
import { SMT256 } from "../../node_modules/smt-rollup/contracts/SMT.sol";
import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { Layer2 } from "../libraries/Layer2.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { Hash } from "../libraries/Hash.sol";


contract Challengeable is ZkOptimisticRollUpStore {
    using Layer2 for *;
    using OPRULib for *;
    using SMT256 for SMT256.OPRU;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

    enum RollUpType { UTXO, Nullifier, Withdrawal}

    event NewProofOfRollUp(RollUpType rollUpType, uint id);

    /** Proof of roll ups */
    ExtendedOPRU[] proofOfUTXORollUp;
    SMT256.OPRU[] proofOfNullifierRollUp;
    OPRU[] proofOfWithdrawalRollUp;

    /** Permission to update Proof of roll up */
    mapping(uint=>mapping(address=>bool)) permissionUTXORU;
    mapping(uint=>mapping(address=>bool)) permissionNullifierRU;
    mapping(uint=>mapping(address=>bool)) permissionWithdrawalRU;

    /** Roll up interaction functions */
    function newProofOfUTXORollUp(
        uint startingRoot,
        uint startingIndex,
        uint[] calldata initialSiblings
    ) external {
        ExtendedOPRU storage opru = proofOfUTXORollUp.push();
        Hash.mimc().initExtendedOPRU(
            opru,
            startingRoot,
            startingIndex,
            initialSiblings
        );
        uint id = proofOfUTXORollUp.length - 1;
        permissionUTXORU[id][msg.sender] = true;
        emit NewProofOfRollUp(RollUpType.UTXO, id);
    }

    function newProofOfNullifierRollUp(bytes32 prevRoot) external {
        SMT256.OPRU storage opru = proofOfNullifierRollUp.push();
        opru.prev = prevRoot;
        opru.next = prevRoot;
        opru.mergedLeaves = bytes32(0);
        uint id = proofOfNullifierRollUp.length - 1;
        permissionNullifierRU[id][msg.sender] = true;
        emit NewProofOfRollUp(RollUpType.Nullifier, id);
    }

    function newProofOfWithdrawalRollUp(
        uint startingRoot,
        uint startingIndex
    ) external {
        OPRU storage opru = proofOfWithdrawalRollUp.push();
        opru.start.root = startingRoot;
        opru.start.index = startingIndex;
        opru.result.root = startingRoot;
        opru.result.index = startingIndex;
        opru.mergedLeaves = bytes32(0);
        uint id = proofOfWithdrawalRollUp.length - 1;
        permissionWithdrawalRU[id][msg.sender] = true;
        emit NewProofOfRollUp(RollUpType.Withdrawal, id);
    }

    function updateProofOfUTXORollUp(uint id, uint[] calldata leaves) external {
        require(permissionUTXORU[id][msg.sender], "Not permitted to update this roll up");
        ExtendedOPRU storage opru = proofOfUTXORollUp[id];
        Hash.mimc().update(opru, leaves);
    }

    function updateProofOfNullifierRollUp(uint id, bytes32[] calldata leaves, bytes32[256][] calldata siblings) external {
        require(permissionNullifierRU[id][msg.sender], "Not permitted to update this roll up");
        SMT256.OPRU storage opru = proofOfNullifierRollUp[id];
        opru.update(leaves, siblings);
    }

    function updateProofOfWithdrawalRollUp(uint id, uint[] calldata initialSiblings, uint[] calldata leaves) external {
        require(permissionWithdrawalRU[id][msg.sender], "Not permitted to update this roll up");
        OPRU storage opru = proofOfWithdrawalRollUp[id];
        Hash.keccak().update(opru, initialSiblings, leaves);
    }

    /**
     * Challenge functions
     * - challengeUTXORollUp
     * - challengeNullifierRollUp
     * - challengeDepositRoot
     * - challengeTransferRoot
     * - challengeWithdrawalRoot
     * - challengeTotalFee
     * - challengeInclusion
     * - challengeTransfer
     * - challengeWithdrawal
     * - challengeUsedNullifier
     * - challengeDuplicatedNullifier
     */

    function challengeUTXORollUp(
        uint utxoRollUpId,
        uint[] calldata deposits,
        bytes calldata
    ) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(2);
        Layer2.ChallengeResult memory result = _challengeResultOfUTXORollUp(submission, utxoRollUpId, deposits);
        _execute(result);
    }

    function challengeNullifierRollUp(
        bytes32[256][] calldata siblings,
        bytes calldata
    ) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfNullifierRollUp(submission, siblings);
        _execute(result);
    }

    function challengeDepositRoot(
        uint[] calldata deposits,
        bytes calldata
    ) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfDepositRoot(submission, deposits);
        _execute(result);
    }

    function challengeTransferRoot(bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfTransferRoot(submission);
        _execute(result);
    }

    function challengeWithdrawalRoot(bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfWithdrawalRoot(submission);
        _execute(result);
    }

    function challengeTotalFee(bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfTotalFee(submission);
        _execute(result);
    }

    function challengeInclusion(
        bool isTransfer,
        uint txIndex,
        uint refIndex,
        bytes calldata
    ) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(3);
        Layer2.ChallengeResult memory result = _challengeResultOfInclusion(
            submission,
            isTransfer,
            txIndex,
            refIndex
        );
        _execute(result);
    }

    function challengeTransfer(uint txIndex, bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfTransfer(submission, txIndex);
        _execute(result);
    }

    function challengeWithdrawal(uint withdrawalIndex, bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfWithdrawal(submission, withdrawalIndex);
        _execute(result);
    }

    function challengeUsedNullifier(
        bytes32 nullifier,
        bytes32[256] calldata sibling,
        bytes calldata
    ) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(2);
        Layer2.ChallengeResult memory result = _challengeResultOfUsedNullifier(submission, nullifier, sibling);
        _execute(result);
    }

    function challengeDuplicatedNullifier(bytes32 nullifier, bytes calldata) external {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfDuplicatedNullifier(submission, nullifier);
        _execute(result);
    }

    function dryChallengeUTXORollUp(
        uint utxoRollUpId,
        uint[] calldata deposits,
        bytes calldata
    )
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(2);
        Layer2.ChallengeResult memory result = _challengeResultOfUTXORollUp(submission, utxoRollUpId, deposits);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeNullifierRollUp(
        bytes32[256][] calldata siblings,
        bytes calldata
    )
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfNullifierRollUp(submission, siblings);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeDepositRoot(uint[] calldata deposits, bytes calldata)
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfDepositRoot(submission, deposits);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTransferRoot(bytes calldata)
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfTransferRoot(submission);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeWithdrawalRoot(bytes calldata)
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfWithdrawalRoot(submission);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeMigrationRoot(bytes calldata)
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfMigrationRoot(submission);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTotalFee(bytes calldata)
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        Layer2.ChallengeResult memory result = _challengeResultOfTotalFee(submission);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeInclusion(
        bool isTransfer,
        uint txIndex,
        uint refIndex,
        bytes calldata
    )
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(3);
        Layer2.ChallengeResult memory result = _challengeResultOfInclusion(
            submission,
            isTransfer,
            txIndex,
            refIndex
        );
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTransfer(uint txIndex, bytes calldata)
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfTransfer(submission, txIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeWithdrawal(uint withdrawalIndex, bytes calldata)
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfWithdrawal(submission, withdrawalIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeMigration(uint migrationIndex, bytes calldata)
        external
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfMigration(submission, migrationIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeUsedNullifier(
        bytes32 nullifier,
        bytes32[256] calldata sibling,
        bytes calldata
    )
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(2);
        Layer2.ChallengeResult memory result = _challengeResultOfUsedNullifier(submission, nullifier, sibling);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeDuplicatedNullifier(bytes32 nullifier, bytes calldata)
        external
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(1);
        Layer2.ChallengeResult memory result = _challengeResultOfDuplicatedNullifier(submission, nullifier);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    /// TODO temporal calculation
    function estimateChallengeCost(bytes calldata) external pure returns (uint256 maxCost) {
        Layer2.Block memory submission = Layer2.blockFromCalldataAt(0);
        return submission.maxChallengeCost();
    }

    /**
     * @notice Check the validity of an inclusion refernce for a nullifier.
     * @dev Each nullifier should be paired with an inclusion reference which is
     *      a root of utxo tree. You can use finalized roots for the reference or
     *      recent block's utxo roots. For the latter, recent REF_DEPTH of utxo
     *      roots are available and it costs. It costs maximum 1800*REF_DEPTH gas
     *      to validating an inclusion reference during a TX challenge process.
     * @param l2BlockHash Layer2 block's hash where to start searching from.
     * @param ref Utxo root which includes the nullifier's origin.
     */
    function isValidRef(bytes32 l2BlockHash, uint256 ref) public view returns (bool) {
        if (l2Chain.finalizedUTXOs[ref]) {
            return true;
        }
        bytes32 parentBlock = l2BlockHash;
        for (uint i = 0; i < REF_DEPTH; i++) {
            parentBlock = l2Chain.parentOf[parentBlock];
            if (l2Chain.utxoRootOf[parentBlock] == ref) {
                return true;
            }
        }
        return false;
    }

    /** Internal functions to help reusable clean code */
    function _getVerifyingKey(
        Layer2.TxType txType,
        uint8 numberOfInputs,
        uint8 numberOfOutputs
    ) internal view returns (SNARKsVerifier.VerifyingKey memory) {
        return vks[Layer2.getSNARKsSignature(txType, numberOfInputs, numberOfOutputs)];
    }

    function _exist(SNARKsVerifier.VerifyingKey memory vk) internal pure returns (bool) {
        if (vk.alfa1.X != 0) {
            return true;
        } else {
            return false;
        }
    }

    function _checkChallengeCondition(Layer2.Proposal storage proposal) internal view {
        /// Check the optimistic roll up is in the challenge period
        require(proposal.challengeDue > block.number, "You missed the challenge period");
        /// Check it is already slashed
        require(!proposal.slashed, "Already slashed");
        /// Check the optimistic rollup exists
        require(proposal.headerHash != bytes32(0), "Not an existing rollup");
    }

    function _forfeitAndReward(address proposerAddr, address challenger) internal {
        Layer2.Proposer storage proposer = l2Chain.proposers[proposerAddr];
        /// Reward
        uint challengeReward = proposer.stake * 2 / 3;
        payable(challenger).transfer(challengeReward);
        /// Forfeit
        proposer.stake = 0;
        proposer.reward = 0;
    }

    function _execute(Layer2.ChallengeResult memory result) private {
        require(result.slash, result.message);

        Layer2.Proposal storage proposal = l2Chain.proposals[result.proposalId];
        /// Check basic challenge conditions
        _checkChallengeCondition(proposal);
        /// Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        proposal.slashed = true; /// Record it as slashed;
        _forfeitAndReward(result.proposer, msg.sender);
        /// TODO log message
    }

    /** Computes challenge here */
    function _challengeResultOfUTXORollUp(Layer2.Block memory submission, uint utxoRollUpId, uint[] memory deposits)
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        require(deposits.root() == submission.header.depositRoot, "Submitted invalid deposit data");

        /// Get total outputs
        uint numOfItems = 0;
        numOfItems += deposits.length;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
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
            Layer2.Transfer memory transfer = submission.body.transfers[i];
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
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "This proposal lets the UTXO tree flush"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        ExtendedOPRU memory proof = proofOfUTXORollUp[utxoRollUpId];
        bool isValidRollUp = proof.opru.verify(
            uint(startingRoot),
            startingIndex,
            uint(submission.header.nextUTXORoot),
            bytes32(0).mergeLeaves(outputs)
        );

        return Layer2.ChallengeResult(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "UTXO roll up"
        );
    }

    /// Possibility to cost a lot of failure gases because of the 'already slashed' submissions
    function _challengeResultOfNullifierRollUp(
        Layer2.Block memory submission,
        bytes32[256][] memory siblings
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        /// Assign a new array
        bytes32[] memory nullifiers = new bytes32[](siblings.length);
        /// Get outputs to append
        uint index = 0;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            for (uint j = 0; j < transfer.nullifiers.length; j++) {
                nullifiers[index++] = transfer.nullifiers[j];
            }
        }
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for (uint j = 0; j < withdrawal.nullifiers.length; j++) {
                nullifiers[index++] = withdrawal.nullifiers[j];
            }
        }

        if (index != siblings.length) {
            return Layer2.ChallengeResult(
                false,
                submission.id,
                submission.header.proposer,
                "Submitted invalid number of siblings"
            );
        }
        /// Get rolled up root
        bytes32 correctRoot = SMT256.rollUp(
            submission.header.prevNullifierRoot,
            nullifiers,
            siblings
        );
        return Layer2.ChallengeResult(
            correctRoot != submission.header.nextNullifierRoot,
            submission.id,
            submission.header.proposer,
            "Nullifier roll up"
        );
    }

    function _challengeResultOfWithdrawalRollUp(Layer2.Block memory submission, uint withdrawalRollUpId)
        private
        view
        returns (Layer2.ChallengeResult memory)
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
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "This proposal lets the UTXO tree flush"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        OPRU memory proof = proofOfWithdrawalRollUp[withdrawalRollUpId];
        bool isValidRollUp = proof.verify(
            uint(startingRoot),
            startingIndex,
            uint(submission.header.nextWithdrawalRoot),
            bytes32(0).mergeLeaves(withdrawalLeaves)
        );

        return Layer2.ChallengeResult(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "UTXO roll up"
        );
    }

    function _challengeResultOfDepositRoot(
        Layer2.Block memory submission,
        uint[] memory deposits
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        uint index = 0;
        bytes32 merged;
        for (uint i = 0; i < submission.body.depositIds.length; i++) {
            merged = bytes32(0);
            Layer2.MassDeposit storage depositsToAdd = l2Chain.depositQueue[submission.body.depositIds[i]];
            if (!depositsToAdd.committed) {
                return Layer2.ChallengeResult(
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
        return Layer2.ChallengeResult(
            submission.header.depositRoot != deposits.root(),
            submission.id,
            submission.header.proposer,
            "Deposit root validation"
        );
    }

    function _challengeResultOfTransferRoot(
        Layer2.Block memory submission
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        return Layer2.ChallengeResult(
            submission.header.transferRoot != submission.body.transfers.root(),
            submission.id,
            submission.header.proposer,
            "Transfer root validation"
        );
    }

    function _challengeResultOfWithdrawalRoot(
        Layer2.Block memory submission
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        return Layer2.ChallengeResult(
            submission.header.withdrawalRoot != submission.body.withdrawals.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfMigrationRoot(
        Layer2.Block memory submission
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        return Layer2.ChallengeResult(
            submission.header.migrationRoot != submission.body.migrations.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfTotalFee(
        Layer2.Block memory submission
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
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
        return Layer2.ChallengeResult(
            totalFee != submission.header.fee,
            submission.id,
            submission.header.proposer,
            "Total fee validation"
        );
    }

    function _challengeResultOfInclusion(
        Layer2.Block memory submission,
        bool isTransfer,
        uint txIndex,
        uint refIndex
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        uint ref;
        if (isTransfer) {
            Layer2.Transfer memory transfer = submission.body.transfers[txIndex];
            ref = transfer.inclusionRefs[refIndex];
        } else {
            Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[txIndex];
            ref = withdrawal.inclusionRefs[refIndex];
        }

        return Layer2.ChallengeResult(
            !isValidRef(submission.header.hash(), ref),
            submission.id,
            submission.header.proposer,
            "Inclusion reference validation"
        );
    }

    function _challengeResultOfTransfer(
        Layer2.Block memory submission,
        uint txIndex
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Transfer memory transfer = submission.body.transfers[txIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            transfer.numberOfInputs != transfer.inclusionRefs.length ||
            transfer.numberOfInputs != transfer.nullifiers.length
        ) {
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            Layer2.TxType.Transfer,
            transfer.numberOfInputs,
            transfer.numberOfOutputs
        );
        if (!_exist(vk)) {
            return Layer2.ChallengeResult(
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
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid transaction. Challenge is not accepted
        return Layer2.ChallengeResult(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid transfer"
        );
    }

    function _challengeResultOfWithdrawal(
        Layer2.Block memory submission,
        uint withdrawalIndex
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[withdrawalIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            withdrawal.numberOfInputs != withdrawal.inclusionRefs.length ||
            withdrawal.numberOfInputs != withdrawal.nullifiers.length
        ) {
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            Layer2.TxType.Withdrawal,
            withdrawal.numberOfInputs,
            0
        );
        if (!_exist(vk)) {
            return Layer2.ChallengeResult(
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
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid withdrawal. Challenge is not accepted
        return Layer2.ChallengeResult(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid withdrawal"
        );
    }

    function _challengeResultOfMigration(
        Layer2.Block memory submission,
        uint migrationIndex
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Migration memory migration = submission.body.migrations[migrationIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if (
            migration.numberOfInputs != migration.inclusionRefs.length ||
            migration.numberOfInputs != migration.nullifiers.length
        ) {
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "Tx body is different with the tx metadata"
            );
        }
        /// Slash if the transaction type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(
            Layer2.TxType.Migration,
            migration.numberOfInputs,
            0
        );
        if (!_exist(vk)) {
            return Layer2.ChallengeResult(
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
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "zk SNARKs says it is a fraud"
            );
        }
        /// Passed all tests. It's a valid migration. Challenge is not accepted
        return Layer2.ChallengeResult(
            false,
            submission.id,
            submission.header.proposer,
            "It's a valid migration"
        );
    }

    function _challengeResultOfUsedNullifier(
        Layer2.Block memory submission,
        bytes32 nullifier,
        bytes32[256] memory sibling
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        bytes32[] memory nullifiers = new bytes32[](1);
        bytes32[256][] memory siblings = new bytes32[256][](1);
        nullifiers[0] = nullifier;
        siblings[0] = sibling;
        bytes32 updatedRoot = SMT256.rollUp(
            submission.header.prevNullifierRoot,
            nullifiers,
            siblings
        );
        return Layer2.ChallengeResult(
            updatedRoot == submission.header.prevNullifierRoot,
            submission.id,
            submission.header.proposer,
            "Double spending validation"
        );
    }

    function _challengeResultOfDuplicatedNullifier(
        Layer2.Block memory submission,
        bytes32 nullifier
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {

        uint count = 0;
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            for (uint j = 0; j < transfer.nullifiers.length; j++) {
                /// Found matched nullifier
                if (transfer.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        for (uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for (uint j = 0; j < withdrawal.nullifiers.length; j++) {
                /// Found matched nullifier
                if (withdrawal.nullifiers[j] == nullifier) count++;
                if (count >= 2) break;
            }
            if (count >= 2) break;
        }
        return Layer2.ChallengeResult(
            count >= 2,
            submission.id,
            submission.header.proposer,
            "Validation of duplicated usage in a block"
        );
    }
}
