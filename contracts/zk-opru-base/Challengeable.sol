pragma solidity >= 0.6.0;

import { StorageRollUpBase } from "../../node_modules/merkle-tree-rollup/contracts/library/StorageRollUpBase.sol";
import { MiMCTree } from "../../node_modules/merkle-tree-rollup/contracts/trees/MiMCTree.sol";
import { SMT256 } from "../../node_modules/smt-rollup/contracts/SMT.sol";
import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { Layer2 } from "../libraries/Layer2.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";

contract Challengeable is StorageRollUpBase, MiMCTree, ZkOptimisticRollUpStore {
    using Layer2 for *;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

    /**
     * Challenge functions
     * - challengeOutputRollUp
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

    function challengeOutputRollUp(
        uint outputRollUpId,
        bytes memory
    ) public {
        _execute(_challengeResultOfOutputRollUpUsingCalldata(outputRollUpId));
    }

    function challengeNullifierRollUp(
        bytes32[256][] memory siblings,
        bytes memory
    ) public {
        _execute(_challengeResultOfNullifierRollUpUsingCalldata(siblings));
    }

    function challengeDepositRoot(bytes memory) public {
        _execute(_challengeResultOfDepositRootUsingCalldata());
    }

    function challengeTransferRoot(bytes memory) public {
        _execute(_challengeResultOfTransferRootUsingCalldata());
    }

    function challengeWithdrawalRoot(bytes memory) public {
        _execute(_challengeResultOfWithdrawalRootUsingCalldata());
    }

    function challengeTotalFee(bytes memory) public {
        _execute(_challengeResultOfTotalFeeUsingCalldata());
    }

    function challengeInclusion(
        bool isTransfer,
        uint txIndex,
        uint refIndex,
        bytes memory
    ) public {
        _execute(_challengeResultOfInclusionUsingCalldata(isTransfer,txIndex,refIndex));
    }

    function challengeTransfer(uint txIndex, bytes memory) public {
        _execute(_challengeResultOfTransferUsingCalldata(txIndex));
    }

    function challengeWithdrawal(uint withdrawalIndex, bytes memory) public {
        _execute(_challengeResultOfWithdrawalUsingCalldata(withdrawalIndex));
    }

    function challengeUsedNullifier(
        bytes32 nullifier,
        bytes32[256] memory sibling,
        bytes memory
    ) public {
        _execute(_challengeResultOfUsedNullifierUsingCalldata(nullifier, sibling));
    }

    function challengeDuplicatedNullifier(bytes32 nullifier, bytes memory) public {
        _execute(_challengeResultOfDuplicatedNullifierUsingCalldata(nullifier));
    }

    function dryChallengeOutputRollUp(
        uint outputRollUpId,
        bytes memory
    )
        public
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfOutputRollUpUsingCalldata(outputRollUpId);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeNullifierRollUp(
        bytes32[256][] memory siblings,
        bytes memory
    )
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfNullifierRollUpUsingCalldata(siblings);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeDepositRoot(bytes memory)
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfDepositRootUsingCalldata();
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTransferRoot(bytes memory)
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfTransferRootUsingCalldata();
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeWithdrawalRoot(bytes memory)
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfWithdrawalRootUsingCalldata();
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTotalFee(bytes memory)
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfTotalFeeUsingCalldata();
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeInclusion(
        bool isTransfer,
        uint txIndex,
        uint refIndex,
        bytes memory
    )
        public
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfInclusionUsingCalldata(isTransfer, txIndex, refIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeTransfer(uint txIndex, bytes memory)
        public
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfTransferUsingCalldata(txIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeWithdrawal(uint withdrawalIndex, bytes memory)
        public
        view
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfWithdrawalUsingCalldata(withdrawalIndex);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeUsedNullifier(
        bytes32 nullifier,
        bytes32[256] memory sibling,
        bytes memory
    )
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfUsedNullifierUsingCalldata(nullifier, sibling);
        return (result.slash, result.proposalId, result.proposer, result.message);
    }

    function dryChallengeDuplicatedNullifier(bytes32 nullifier, bytes memory)
        public
        pure
        returns (
            bool slash,
            bytes32 proposalId,
            address proposer,
            string memory message
        )
    {
        Layer2.ChallengeResult memory result;
        result = _challengeResultOfDuplicatedNullifierUsingCalldata(nullifier);
        return (result.slash, result.proposalId, result.proposer, result.message);
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
        if(l2Chain.finalizedTrees[ref]) return true;
        bytes32 parentBlock = l2BlockHash;
        for(uint i = 0; i < REF_DEPTH; i++) {
            parentBlock = l2Chain.parentOf[parentBlock];
            if(l2Chain.utxoRootOf[parentBlock] == ref) return true;
        }
        return false;
    }

    /// TODO temporal calculation
    function estimateChallengeCost(bytes memory) public pure returns (uint256 maxCost) {
        Layer2.Block memory submission = Layer2.blockFromCalldata(0);
        return submission.maxChallengeCost();
    }

    /** Internal functions to help reusable clean code */
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

    function _getVerifyingKey(
        uint8 numberOfInputs,
        uint8 numberOfOutputs
    ) internal view returns (SNARKsVerifier.VerifyingKey memory) {
        return vks[numberOfInputs][numberOfOutputs];
    }

    function _exist(SNARKsVerifier.VerifyingKey memory vk) internal pure returns (bool) {
        if(vk.alfa1.X != 0) return true;
        else return false;
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

    /** Computes challenge here */
    function _challengeResultOfOutputRollUpUsingCalldata(uint outputRollUpId)
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(32);

        /// Get total outputs
        uint numOfOutputs = 0;
        numOfOutputs += submission.body.deposits.length;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            numOfOutputs += transfer.outputs.length;
        }

        /// Assign a new array
        uint[] memory outputs = new uint[](numOfOutputs);
        /// Get outputs to append
        uint index = 0;
        for(uint i = 0; i < submission.body.deposits.length; i++) {
            outputs[index++] = uint(submission.body.deposits[i]);
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.outputs.length; j++) {
                outputs[index++] = uint(transfer.outputs[j]);
            }
        }

        /// Start a new tree if there's no room to add the new outputs
        uint startingIndex;
        uint startingRoot;
        if(submission.header.prevUTXOIndex + numOfOutputs < POOL_SIZE) {
            /// it uses the latest tree
            startingIndex = submission.header.prevUTXOIndex;
            startingRoot = submission.header.prevUTXORoot;
        } else {
            /// start a new tree
            startingIndex = 0;
            startingRoot = 0;
        }
        /// Submitted invalid next output index
        if(submission.header.nextUTXOIndex != (startingIndex + numOfOutputs)) {
            /// should archive the previous tree and start a new one
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "This proposal lets the UTXO tree flush"
            );
        }

        /// Check validity of the roll up using the storage based MiMC roll up
        bool isValidRollUp = verifyRollUp(
            outputRollUpId,
            uint(startingRoot),
            startingIndex,
            uint(submission.header.nextUTXORoot),
            outputs
        );
        return Layer2.ChallengeResult(
            !isValidRollUp,
            submission.id,
            submission.header.proposer,
            "UTXO roll up"
        );
    }

    /// Possibility to cost a lot of failure gases because of the 'already slashed' submissions
    function _challengeResultOfNullifierRollUpUsingCalldata(
        bytes32[256][] memory siblings
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        /// 96 = 32 bytes (nested array size) + 32 bytes (total data size) + 32 bytes (array length)
        uint siblingCalldataSize = 256*32*siblings.length + 96;
        Layer2.Block memory submission = Layer2.blockFromCalldata(siblingCalldataSize);

        /// Assign a new array
        bytes32[] memory nullifiers = new bytes32[](siblings.length);
        /// Get outputs to append
        uint index = 0;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.nullifiers.length; j++) {
                nullifiers[index++] = transfer.nullifiers[j];
            }
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for(uint j = 0; j < withdrawal.nullifiers.length; j++) {
                nullifiers[index++] = withdrawal.nullifiers[j];
            }
        }

        if(index != siblings.length) {
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

    function _challengeResultOfDepositRootUsingCalldata()
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(0);
        return Layer2.ChallengeResult(
            submission.header.depositRoot != submission.body.deposits.root(),
            submission.id,
            submission.header.proposer,
            "Deposit root validation"
        );
    }

    function _challengeResultOfTransferRootUsingCalldata()
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(0);
        return Layer2.ChallengeResult(
            submission.header.transferRoot != submission.body.transfers.root(),
            submission.id,
            submission.header.proposer,
            "Transfer root validation"
        );
    }

    function _challengeResultOfWithdrawalRootUsingCalldata()
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(0);
        return Layer2.ChallengeResult(
            submission.header.withdrawalRoot != submission.body.withdrawals.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfTotalFeeUsingCalldata()
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(0);
        uint totalFee = 0;
        for(uint i = 0; i < submission.body.transfers.length; i ++) {
            totalFee += submission.body.transfers[i].fee;
        }
        for(uint i = 0; i < submission.body.withdrawals.length; i ++) {
            totalFee += submission.body.withdrawals[i].fee;
        }
        return Layer2.ChallengeResult(
            totalFee != submission.header.fee,
            submission.id,
            submission.header.proposer,
            "Total fee validation"
        );
    }

    function _challengeResultOfInclusionUsingCalldata(
        bool isTransfer,
        uint txIndex,
        uint refIndex
    )
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(96);
        uint ref;
        if(isTransfer) {
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

    function _challengeResultOfTransferUsingCalldata(uint txIndex)
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(32);
        Layer2.Transfer memory transfer = submission.body.transfers[txIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if(
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
        /// Slash if the transfer type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(transfer.numberOfInputs, transfer.numberOfOutputs);
        if(!_exist(vk)) {
            return Layer2.ChallengeResult(
                true,
                submission.id,
                submission.header.proposer,
                "Unsupported tx type"
            );
        }
        /// Slash if its zk SNARKs verification returns false
        uint[] memory inputs = new uint[](3 + 2*transfer.numberOfInputs + transfer.numberOfOutputs);
        uint index = 0;
        inputs[index++] = uint(transfer.numberOfInputs);
        inputs[index++] = uint(transfer.numberOfOutputs);
        inputs[index++] = uint(transfer.fee);
        for(uint i = 0; i < transfer.numberOfInputs; i++) {
            inputs[index++] = uint(transfer.inclusionRefs[i]);
        }
        for(uint i = 0; i < transfer.numberOfInputs; i++) {
            inputs[index++] = uint(transfer.nullifiers[i]);
        }
        for(uint i = 0; i < transfer.numberOfOutputs; i++) {
            inputs[index++] = uint(transfer.outputs[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(transfer.proof);
        if(!vk.zkSNARKs(inputs, proof)) {
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
            "Passed all tests"
        );
    }

    function _challengeResultOfWithdrawalUsingCalldata(uint withdrawalIndex)
        private
        view
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(32);
        Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[withdrawalIndex];

        /// Slash if the length of the array is not same with the tx metadata
        if(
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
        /// Slash if the transfer type is not supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(withdrawal.numberOfInputs, 0);
        if(!_exist(vk)) {
            return Layer2.ChallengeResult(
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
        inputs[index++] = uint(withdrawal.numberOfInputs);
        for(uint i = 0; i < withdrawal.numberOfInputs; i++) {
            inputs[index++] = uint(withdrawal.inclusionRefs[i]);
        }
        for(uint i = 0; i < withdrawal.numberOfInputs; i++) {
            inputs[index++] = uint(withdrawal.nullifiers[i]);
        }
        SNARKsVerifier.Proof memory proof = SNARKsVerifier.proof(withdrawal.proof);
        if(!vk.zkSNARKs(inputs, proof)) {
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
            "Passed all tests"
        );
    }

    function _challengeResultOfUsedNullifierUsingCalldata(
        bytes32 nullifier,
        bytes32[256] memory sibling
    )
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(32);
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

    function _challengeResultOfDuplicatedNullifierUsingCalldata(bytes32 nullifier)
        private
        pure
        returns (Layer2.ChallengeResult memory)
    {
        Layer2.Block memory submission = Layer2.blockFromCalldata(32);

        uint count = 0;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.nullifiers.length; j++) {
                /// Found matched nullifier
                if(transfer.nullifiers[j] == nullifier) count++;
                if(count >= 2) break;
            }
            if(count >= 2) break;
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Layer2.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for(uint j = 0; j < withdrawal.nullifiers.length; j++) {
                /// Found matched nullifier
                if(withdrawal.nullifiers[j] == nullifier) count++;
                if(count >= 2) break;
            }
            if(count >= 2) break;
        }
        return Layer2.ChallengeResult(
            count >= 2,
            submission.id,
            submission.header.proposer,
            "Validation of duplicated usage in a block"
        );
    }


}
