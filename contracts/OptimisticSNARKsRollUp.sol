pragma solidity >= 0.6.0;

import { IERC20 } from "./IERC20.sol";
import { SMT256 } from "smt-rollup/contracts/SMT.sol";
import { Types } from "./Types.sol";
import { SNARKsVerifier } from "./SNARKs.sol";

contract OptimisticSNARKsRollUp {
    using Types for *;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;

    mapping(bytes32=>bool) refs;
    bytes32 public outputRoot;
    bytes32 public nullifierRoot;

    uint public challengePeriod;
    uint public challengeLimit;
    uint public minimumStake;

    mapping(address=>Types.Proposer) public proposers;
    mapping(bytes32=>Types.Proposal) public proposals;
    mapping(bytes32=>Types.Deposit) public deposits;

    IERC20 public erc20;
    bool isERCPool;

    constructor(
        uint _challengePeriod,
        uint _minimumStake,
        uint _challengeLimit,
        address tokenAddr
    ) public {
        challengePeriod = _challengePeriod;
        challengeLimit = _challengeLimit;
        minimumStake = _minimumStake;
        erc20 = IERC20(tokenAddr);
        isERCPool = (tokenAddr != address(0)) ? true : false;
    }

    function deposit(bytes32 note, uint amount, uint fee, uint[8] memory zkProof) public payable {
        require(note != bytes32(0), "Note hash can not be zero");
        // TODO
        // verify zkProof
        // get fund
        if(isERCPool) {
            // ERC pool
            erc20.transferFrom(msg.sender, address(this), amount + fee);
        } else {
            // Ether pool
            require(amount + fee == msg.value, "Amount + Fee does not match with the paid Ether");
        }
        // Record deposit
        deposits[note] = Types.Deposit(note, amount, fee);
    }

    function cancelDeposit(bytes32 note, uint[8] memory zkProof) public {
        // TODO
        // verify zk Proof
        // find deposit and try to cancel
        // send the fee back
        require(deposits[note].note != bytes32(0), "Does not exist or already committed");
        if(isERCPool) {
            erc20.transfer(msg.sender, (deposits[note].fee + deposits[note].amount));
        } else {
            payable(msg.sender).transfer((deposits[note].fee + deposits[note].amount));
        }
        delete deposits[note];
    }

    // Coordinator function
    function register() public payable {
        require(msg.value >= minimumStake, "Should stake more than minimum amount of ETH");
        Types.Proposer storage proposer = proposers[msg.sender];
        proposer.stake += msg.value;
    }

    // Coordinator function
    function deregister() public {
        address payable proposerAddr = msg.sender;
        Types.Proposer storage proposer = proposers[proposerAddr];
        require(proposer.exitAllowance <= block.number, "Still in the challenge period");
        proposerAddr.transfer(proposer.reward + proposer.stake);
        proposer.stake = 0;
        proposer.reward = 0;
    }

    // Coordinator function
    function withdrawReward(uint amount) public {
        address payable proposerAddr = msg.sender;
        Types.Proposer storage proposer = proposers[proposerAddr];
        require(proposer.reward >= amount, "You can't withdraw more than you have");
        proposerAddr.transfer(amount);
        proposer.reward -= amount;
    }

    function propose(bytes memory serializedBlock) public {
        Types.Block memory submittedBlock = Types.blockFromCalldata(0);
        // The message sender address should be same with the proposer address
        require(submittedBlock.header.proposer == msg.sender, "Coordinator account is different with the message sender");
        Types.Proposer storage proposer = proposers[msg.sender];
        // Check permission
        require(isProposable(proposer), "Not allowed to propose");
        // Duplicated proposal is not allowed
        require(proposals[submittedBlock.id].headerHash == bytes32(0), "Already submitted");
        // Do not exceed maximum challenging cost
        require(submittedBlock.maxChallengeCost() < challengeLimit, "Its challenge cost exceeds the limit");
        // Save opru proposal
        proposals[submittedBlock.id] = Types.Proposal(
            submittedBlock.header.hash(),
            block.number + challengePeriod,
            false
        );
        // Update exit allowance period
        proposer.exitAllowance = block.number + challengePeriod;
    }

    function finalize(bytes memory serializedFinalization) public {
        Types.Finalization memory finalization = Types.finalizationFromCalldata(0);
        Types.Proposal storage proposal = proposals[finalization.blockId];
        // Check submitted deposit hash
        require(
            finalization.deposits.root() == finalization.header.depositRoot,
            "Different with the submitted deposits"
        );
        // Check submitted withdrawal hash
        require(
            finalization.withdrawals.root() == finalization.header.withdrawalRoot,
            "Different with the submitted withdrawals"
        );
        // Check header hash
        require(finalization.header.hash() == proposal.headerHash, "Invalid header data");
        // Should not be slashed
        require(!proposal.slashed, "Slashed roll up can't be finalized");
        // The roots of its parent state should be correct
        require(finalization.header.prevOutputRoot == outputRoot, "Previous output root is different with the current");
        require(finalization.header.prevNullifierRoot == nullifierRoot, "Previous nullifier root is different with the current");
        // Update the current root
        outputRoot = finalization.header.nextOutputRoot;
        nullifierRoot = finalization.header.nextNullifierRoot;
        // Update references
        refs[outputRoot] = true;
        uint totalFee = finalization.header.fee;
        // Execute deposits and collect fees
        for(uint i = 0; i < finalization.deposits.length; i++) {
            Types.Deposit storage deposit = deposits[finalization.deposits[i]];
            require(deposit.note != bytes32(0), "Deposit does not exist");
            totalFee += deposit.fee;
            delete deposits[finalization.deposits[i]]; // This line will save gas
        }

        // Execute withdrawals and collect fees
        for(uint i = 0; i < finalization.withdrawals.length; i++) {
            Types.WithdrawalNote memory note = finalization.withdrawals[i];
            totalFee += note.fee;
            if(isERCPool) {
                erc20.transfer(note.to, note.amount);
            } else {
                payable(note.to).transfer(note.amount);
            }
        }
        Types.Proposer storage proposer = proposers[finalization.header.proposer];
        proposer.reward += totalFee;

        // Give fee to the proposer
        proposer.reward += totalFee;
    }

    function isProposable(address proposerAddr) public view returns (bool) {
        return isProposable(proposers[proposerAddr]);
    }

    function isProposable(Types.Proposer memory  proposer) internal view returns (bool) {
        // You can add more consensus logic here
        if(proposer.stake <= minimumStake) {
            return false;
        } else {
            return true;
        }
    }

    function checkChallengeCondition(Types.Proposal storage proposal) internal view {
        // Check the optimistic roll up is in the challenge period
        require(proposal.challengeDue > block.number, "You missed the challenge period");
        // Check it is already slashed
        require(!proposal.slashed, "Already slashed");
        // Check the optimistic rollup exists
        require(proposal.headerHash != bytes32(0), "Not an existing rollup");
    }

    function forfeitAndReward(address proposerAddr, address payable challenger) internal {
        Types.Proposer storage proposer = proposers[proposerAddr];
        // Reward
        uint challengeReward = proposer.stake * 2 / 3;
        challenger.transfer(challengeReward);
        // Forfeit
        proposer.stake = 0;
        proposer.reward = 0;
    }

    // TODO temporal calculation
    function estimateChallengeCost(bytes memory data) public pure returns (uint256 maxCost) {
        Types.Block memory submission = Types.blockFromCalldata(0);
        return submission.maxChallengeCost();
    }


    // Possibility to cost a lot of failure gases because of the 'already slashed'
    function challengeOutputRollUp(bytes32[256][] memory siblings, bytes memory data) public {
        // 96 = 32 bytes (nested array size) + 32 bytes (total data size) + 32 bytes (array length)
        uint siblingCalldataSize = 256*32*siblings.length + 96;
        Types.Block memory submission = Types.blockFromCalldata(siblingCalldataSize);
        challengeOutputRollUp(submission, siblings);
    }

    function challengeOutputRollUp(Types.Block memory submission, bytes32[256][] memory siblings) internal challenge(submission) {
        // Assign a new array
        bytes32[] memory outputs = new bytes32[](siblings.length);
        // Get outputs to append
        uint index = 0;
        for(uint i = 0; i < submission.body.deposits.length; i++) {
            outputs[index++] = submission.body.deposits[i];
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.outputs.length; j++) {
                outputs[index++] = transfer.outputs[j];
            }
        }
        require(
            index == siblings.length,
            "The length of the sibling data array should be same with the total outputs"
        );
        // Get rolled up root
        bytes32 correctRoot = SMT256.rollUp(
            submission.header.prevOutputRoot,
            outputs,
            siblings
        );
        require(correctRoot != submission.header.nextOutputRoot, "Next output root should not be correct");
    }

    function challengeNullifierRollUp(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeDepositRoot(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeTransferRoot(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeWithdrawalRoot(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeTotalFee(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeTransfer(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeWithdrawal(Types.Block memory submission) internal challenge(submission) {
    }

    function challengeInclusion(Types.Block memory submission) internal challenge(submission) {
    }


    modifier challenge(Types.Block memory submission) {
        Types.Proposal storage proposal = proposals[submission.id];
        // Check basic challenge conditions
        checkChallengeCondition(proposal);
        // Check type specific conditions
        _;
        // Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        proposal.slashed = true; // Record it as slashed;
        forfeitAndReward(submission.header.proposer, msg.sender);
    }
    /**
    function outputRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function nullifierRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function verifyDepositRoot(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyTransferRoot(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyWithdrawalRoot(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyFee(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyOutputRollUp(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyNullifierRollUp(Types.Block memory rollUpBlock) public pure returns (bool);
    function verifyTransfer(Types.Transfer memory transfer) public view returns (bool);
    function verifyWithdrawal(Types.Withdrawal memory withdrawal) public view returns (bool);
    function verifyNonInclusion(bytes32 nullifier, bytes32[] memory siblings) public view returns (bool);
    */
}
