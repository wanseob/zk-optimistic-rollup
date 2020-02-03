pragma solidity >= 0.6.0;

import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { Layer1 } from "../libraries/Layer1.sol";
import { Layer2 } from "../libraries/Layer2.sol";


contract Coordinatable is ZkOptimisticRollUpStore {
    using Layer2 for *;
    using Layer1 for address;

    /**
     * Coordinator interaction functions
     * - register
     * - deregister
     * - withdrawReward
     * - propose
     * - finalize
     */
    function register() public payable {
        require(msg.value >= MINIMUM_STAKE, "Should stake more than minimum amount of ETH");
        Layer2.Proposer storage proposer = l2Chain.proposers[msg.sender];
        proposer.stake += msg.value;
    }

    function deregister() public {
        address payable proposerAddr = msg.sender;
        Layer2.Proposer storage proposer = l2Chain.proposers[proposerAddr];
        require(proposer.exitAllowance <= block.number, "Still in the challenge period");
        proposerAddr.transfer(proposer.reward + proposer.stake);
        proposer.stake = 0;
        proposer.reward = 0;
    }

    function withdrawReward(uint amount) public {
        address payable proposerAddr = msg.sender;
        Layer2.Proposer storage proposer = l2Chain.proposers[proposerAddr];
        require(proposer.reward >= amount, "You can't withdraw more than you have");
        proposerAddr.transfer(amount);
        proposer.reward -= amount;
    }

    function propose(bytes memory) public {
        Layer2.Block memory submittedBlock = Layer2.blockFromCalldataAt(0);
        /// The message sender address should be same with the proposer address
        require(submittedBlock.header.proposer == msg.sender, "Coordinator account is different with the message sender");
        Layer2.Proposer storage proposer = l2Chain.proposers[msg.sender];
        /// Check permission
        require(isProposable(msg.sender), "Not allowed to propose");
        /// Duplicated proposal is not allowed
        require(l2Chain.proposals[submittedBlock.id].headerHash == bytes32(0), "Already submitted");
        /** LEGACY
        /// Do not exceed maximum challenging cost
        require(submittedBlock.maxChallengeCost() < CHALLENGE_LIMIT, "Its challenge cost exceeds the limit");
        */
        /// Save opru proposal
        bytes32 currentBlockHash = submittedBlock.header.hash();
        l2Chain.proposals[submittedBlock.id] = Layer2.Proposal(
            currentBlockHash,
            block.number + CHALLENGE_PERIOD,
            false
        );
        /// Record l2 chain
        l2Chain.parentOf[currentBlockHash] = submittedBlock.header.parentBlock;
        /// Record reference for the inclusion proofs
        l2Chain.utxoRootOf[currentBlockHash] = submittedBlock.header.nextUTXORoot;
        /// Update exit allowance period
        proposer.exitAllowance = block.number + CHALLENGE_PERIOD;
    }

    /**
     * @dev Possible attack scenario
     - when (ERC20.transfer) does not work
     * TODO change this to a roll up version
     */
    function finalize(bytes memory) public {
        Layer2.Finalization memory finalization = Layer2.finalizationFromCalldataAt(0);
        Layer2.Proposal storage proposal = l2Chain.proposals[finalization.blockId];
        /// Check requirements
        require(finalization.depositIds.root() == finalization.header.depositRoot, "Submitted different deposit root");
        require(finalization.header.hash() == proposal.headerHash, "Invalid header data");
        require(!proposal.slashed, "Slashed roll up can't be finalized");
        require(finalization.header.parentBlock == l2Chain.latest, "The latest block should be its parent");

        uint totalFee = finalization.header.fee;
        /// Execute deposits and collect fees
        for (uint i = 0; i < finalization.depositIds.length; i++) {
            Layer2.MassDeposit storage deposit = l2Chain.depositQueue[finalization.depositIds[i]];
            require(deposit.committed == true, "Deposit should have committed status");
            totalFee += deposit.fee;
            delete l2Chain.depositQueue[finalization.depositIds[i]];
        }
        /// Record mass migrations and collect fees
        for (uint i = 0; i < finalization.migrations.length; i++) {
            l2Chain.migrations.push() = finalization.migrations[i];
        }

        /// Update withdrawable every finalization
        require(l2Chain.withdrawables.length >= 2, "not initialized blockchain");
        Layer2.Withdrawable storage latest = l2Chain.withdrawables[l2Chain.withdrawables.length - 1];
        require(latest.root == finalization.header.prevWithdrawalRoot, "Different withdrawal tree");
        require(latest.index == finalization.header.prevWithdrawalIndex, "Different withdrawal tree");
        if (finalization.header.prevWithdrawalIndex > finalization.header.nextWithdrawalIndex) {
            l2Chain.withdrawables.push();
        }
        Layer2.Withdrawable storage target = l2Chain.withdrawables[l2Chain.withdrawables.length - 1];
        target.root = finalization.header.nextWithdrawalRoot;
        target.index = finalization.header.nextWithdrawalIndex;

        /// Update the daily snapshot of withdrawable tree
        if (l2Chain.snapshotTimestamp + 1 days < now) {
            l2Chain.snapshotTimestamp = now;
            l2Chain.withdrawables[0].root = target.root;
            l2Chain.withdrawables[0].index = target.index;
        }

        /// Give fee to the proposer
        Layer2.Proposer storage proposer = l2Chain.proposers[finalization.header.proposer];
        proposer.reward += totalFee;

        /// Update OPRU chain
        l2Chain.latest = proposal.headerHash;
    }

    function isProposable(address proposerAddr) public view returns (bool) {
        Layer2.Proposer memory  proposer = l2Chain.proposers[proposerAddr];
        /// You can add more consensus logic here
        if (proposer.stake <= MINIMUM_STAKE) {
            return false;
        } else {
            return true;
        }
    }
}

/** Dev notes */
///  TODO - If the gas usage exceeds the challenge limit, the proposer will get slashed
///  TODO - instant withdrawal
///  TODO - guarantee of tx including
///  Some thoughts - Possibility to cost a lot of gas because of the racing for the slash reward
