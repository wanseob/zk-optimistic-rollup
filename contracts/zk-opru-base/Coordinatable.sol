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
        Layer2.Block memory submittedBlock = Layer2.blockFromCalldata(0);
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
        Layer2.Finalization memory finalization = Layer2.finalizationFromCalldata(0);
        Layer2.Proposal storage proposal = l2Chain.proposals[finalization.blockId];
        /// Check requirements
        require(
            finalization.deposits.root() == finalization.header.depositRoot,
            "Submitted different deposit root"
        );
        require(
            finalization.withdrawals.root() == finalization.header.withdrawalRoot,
            "Submitted different withdrawal root"
        );
        require(finalization.header.hash() == proposal.headerHash, "Invalid header data");
        require(!proposal.slashed, "Slashed roll up can't be finalized");
        require(finalization.header.parentBlock == l2Chain.latestBlock, "The latest block should be its parent");
        /** LEGACY
        /// The roots of its parent state should be correct
        require(finalization.header.prevUTXORoot == utxoRootOf, "Previous utxo root is different with the current");
        require(finalization.header.prevNullifierRoot == nullifierRoot, "Previous nullifier root is different with the current");
        /// Update the current root
        utxoRootOf = finalization.header.nextUTXORoot;
        nullifierRoot = finalization.header.nextNullifierRoot;
        */
        uint totalFee = finalization.header.fee;
        /// Execute deposits and collect fees
        for(uint i = 0; i < finalization.deposits.length; i++) {
            Layer2.Deposit storage _deposit = l2Chain.pendingDeposits[finalization.deposits[i]];
            require(_deposit.note != bytes32(0), "Deposit does not exist");
            totalFee += _deposit.fee;
            delete l2Chain.pendingDeposits[finalization.deposits[i]]; /// This line will save gas
        }

        /// Execute withdrawals and collect fees
        for(uint i = 0; i < finalization.withdrawals.length; i++) {
            Layer2.WithdrawalNote memory note = finalization.withdrawals[i];
            totalFee += note.fee;
            l1Asset.withdrawFromLayer2(note.to, note.amount);
        }
        Layer2.Proposer storage proposer = l2Chain.proposers[finalization.header.proposer];
        proposer.reward += totalFee;

        /// Give fee to the proposer
        proposer.reward += totalFee;

        /// Update OPRU chain
        l2Chain.latestBlock = proposal.headerHash;
    }

    function isProposable(address proposerAddr) public view returns (bool) {
        Layer2.Proposer memory  proposer = l2Chain.proposers[proposerAddr];
        /// You can add more consensus logic here
        if(proposer.stake <= MINIMUM_STAKE) {
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
