pragma solidity >= 0.6.0;

import { IERC20 } from "./IERC20.sol";
import { SMT256 } from "smt-rollup/contracts/SMT.sol";
import { Types } from "./Types.sol";
import { Pairing } from "./Pairing.sol";
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
    mapping(uint8=>mapping(uint8=>SNARKsVerifier.VerifyingKey)) vks;
    address admin;

    IERC20 public erc20;
    bool isERCPool;

    constructor(
        uint _challengePeriod,
        uint _minimumStake,
        uint _challengeLimit,
        address _tokenAddr,
        address _initialAdmin
    ) public {
        challengePeriod = _challengePeriod;
        challengeLimit = _challengeLimit;
        minimumStake = _minimumStake;
        erc20 = IERC20(_tokenAddr);
        isERCPool = (_tokenAddr != address(0)) ? true : false;
        admin = _initialAdmin;
    }

    /**
     * Admin functions are only available before completing the setup
     */
    modifier onlyAdmin {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    function completeSetup() public onlyAdmin {
        delete admin;
    }

    function registerVk(
        uint8 numOfInputs,
        uint8 numOfOutputs,
        uint[2] memory alfa1,
        uint[2][2] memory beta2,
        uint[2][2] memory gamma2,
        uint[2][2] memory delta2,
        uint[2][] memory IC
    ) public onlyAdmin {
        SNARKsVerifier.VerifyingKey storage vk = vks[numOfInputs][numOfOutputs];
        vk.alfa1 = Pairing.G1Point(alfa1[0], alfa1[1]);
        vk.beta2 = Pairing.G2Point(beta2[0], beta2[1]);
        vk.gamma2 = Pairing.G2Point(gamma2[0], gamma2[1]);
        vk.delta2 = Pairing.G2Point(delta2[0], delta2[1]);
        for(uint i = 0; i < IC.length; i++) {
            vk.IC.push(Pairing.G1Point(IC[i][0], IC[i][1]));
        }
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
        require(_isProposable(proposer), "Not allowed to propose");
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
        return _isProposable(proposers[proposerAddr]);
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
        if(correctRoot == submission.header.nextOutputRoot) {
            revert("Challenge failed. Correct next output root is submitted");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    // Possibility to cost a lot of failure gases because of the 'already slashed'
    function challengeNullifierRollUp(bytes32[256][] memory siblings, bytes memory data) public {
        // 96 = 32 bytes (nested array size) + 32 bytes (total data size) + 32 bytes (array length)
        uint siblingCalldataSize = 256*32*siblings.length + 96;
        Types.Block memory submission = Types.blockFromCalldata(siblingCalldataSize);

        // Assign a new array
        bytes32[] memory nullifiers = new bytes32[](siblings.length);
        // Get outputs to append
        uint index = 0;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.nullifiers.length; j++) {
                nullifiers[index++] = transfer.nullifiers[j];
            }
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for(uint j = 0; j < withdrawal.nullifiers.length; j++) {
                nullifiers[index++] = withdrawal.nullifiers[j];
            }
        }
        require(
            index == siblings.length,
            "The length of the sibling array should be equal to the total nullifiers"
        );
        // Get rolled up root
        bytes32 correctRoot = SMT256.rollUp(
            submission.header.prevNullifierRoot,
            nullifiers,
            siblings
        );
        if(correctRoot == submission.header.nextNullifierRoot) {
            revert("Next output root is correct");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function challengeDepositRoot(bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(0);
        if(submission.header.depositRoot == submission.body.deposits.root()) {
            revert("Deposit root is correct");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function challengeTransferRoot(bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(0);
        if(submission.header.transferRoot == submission.body.transfers.root()) {
            revert("Transfer root is correct");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function challengeWithdrawalRoot(bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(0);
        if(submission.header.withdrawalRoot == submission.body.withdrawals.root()) {
            revert("Withdrawal root is correct");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function challengeTotalFee(bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(0);
        uint totalFee = 0;
        for(uint i = 0; i < submission.body.transfers.length; i ++) {
            totalFee += submission.body.transfers[i].fee;
        }
        for(uint i = 0; i < submission.body.withdrawals.length; i ++) {
            totalFee += submission.body.withdrawals[i].fee;
        }
        if(totalFee == submission.header.fee) {
            revert("Total fee is correct");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function challengeTransfer(uint txIndex, bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(32);
        Types.Transfer memory transfer = submission.body.transfers[txIndex];

        // The length of the array should be as described
        if(transfer.numberOfInputs != transfer.inclusionRefs.length) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        if(transfer.numberOfInputs != transfer.nullifiers.length) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Check inclusion reference exists
        for(uint i = 0; i < transfer.numberOfInputs; i++) {
            // Accept challenge if any of the inclusion references does not exist
            if(!refs[transfer.inclusionRefs[i]]) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        }
        // Check the transfer type is supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(transfer.numberOfInputs, transfer.numberOfOutputs);
        if(!_exist(vk)) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Check zkSNARKs validity
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
        if(!vk.zkSNARKs(inputs, proof)) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Passed all tests. It's a valid transaction. Challenge is not accepted
        revert("Passed all tests. The transfer is a valid transaction");
    }

    function challengeWithdrawal(uint withdrawalIndex, bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(32);
        Types.Withdrawal memory withdrawal = submission.body.withdrawals[withdrawalIndex];

        // return means this challenge is accepted
        // The length of the array should be as described
        if(withdrawal.numberOfInputs != withdrawal.inclusionRefs.length) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        if(withdrawal.numberOfInputs != withdrawal.nullifiers.length) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Check inclusion reference exists
        for(uint i = 0; i < withdrawal.numberOfInputs; i++) {
            if(!refs[withdrawal.inclusionRefs[i]]) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        }
        // Check the transfer type is supported
        SNARKsVerifier.VerifyingKey memory vk = _getVerifyingKey(withdrawal.numberOfInputs, 0);
        if(!_exist(vk)) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Check zkSNARKs validity
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
        if(!vk.zkSNARKs(inputs, proof)) _executeSlash(submission.id, submission.header.proposer, msg.sender);
        // Passed all tests. It's a valid withdrawal. Challenge is not accepted
        revert("Passed all tests. The withdrawal is a valid transaction");
    }

    function challengeUsedNullifier(bytes32 nullifier, bytes32[256] memory sibling, bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(32);
        bytes32[] memory nullifiers = new bytes32[](1);
        bytes32[256][] memory siblings = new bytes32[256][](1);
        nullifiers[0] = nullifier;
        siblings[0] = sibling;
        bytes32 updatedRoot = SMT256.rollUp(
            submission.header.prevNullifierRoot,
            nullifiers,
            siblings
        );
        if(updatedRoot != submission.header.prevNullifierRoot) {
            revert("Submitted nullifier hasn't been used. New items should not change the root");
        }

        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.nullifiers.length; j++) {
                // Found matched nullifier
                if(transfer.nullifiers[j] == nullifier) _executeSlash(submission.id, submission.header.proposer, msg.sender);
            }
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for(uint j = 0; j < withdrawal.nullifiers.length; j++) {
                // Found matched nullifier
                if(withdrawal.nullifiers[j] == nullifier) _executeSlash(submission.id, submission.header.proposer, msg.sender);
            }
        }
        // The submitted block does not include the nullifier
        revert("Failed to find the nullifier in the submitted transactions");
    }

    function challengeDuplicatedNullifier(bytes32 nullifier, bytes memory data) public {
        Types.Block memory submission = Types.blockFromCalldata(32);

        uint count = 0;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Transfer memory transfer = submission.body.transfers[i];
            for(uint j = 0; j < transfer.nullifiers.length; j++) {
                // Found matched nullifier
                if(transfer.nullifiers[j] == nullifier) count++;
            }
        }
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Types.Withdrawal memory withdrawal = submission.body.withdrawals[i];
            for(uint j = 0; j < withdrawal.nullifiers.length; j++) {
                // Found matched nullifier
                if(withdrawal.nullifiers[j] == nullifier) count++;
            }
        }
        if(count < 2) {
            revert("The nullifier is not used more than twice");
        }
        _executeSlash(submission.id, submission.header.proposer, msg.sender);
    }

    function _executeSlash(bytes32 submissionId, address proposer, address challenger) internal {
        Types.Proposal storage proposal = proposals[submissionId];
        // Check basic challenge conditions
        _checkChallengeCondition(proposal);
        // Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        proposal.slashed = true; // Record it as slashed;
        _forfeitAndReward(proposer, challenger);
    }

    function _getVerifyingKey(
        uint8 numberOfInputs,
        uint8 numberOfOutputs
    ) internal returns (SNARKsVerifier.VerifyingKey memory) {
        SNARKsVerifier.VerifyingKey memory vk = vks[numberOfInputs][numberOfOutputs];
    }

    function _exist(SNARKsVerifier.VerifyingKey memory vk) internal returns (bool) {
        if(vk.alfa1.X != 0) return true;
        else return false;
    }

    function _isProposable(Types.Proposer memory  proposer) internal view returns (bool) {
        // You can add more consensus logic here
        if(proposer.stake <= minimumStake) {
            return false;
        } else {
            return true;
        }
    }

    function _checkChallengeCondition(Types.Proposal storage proposal) internal view {
        // Check the optimistic roll up is in the challenge period
        require(proposal.challengeDue > block.number, "You missed the challenge period");
        // Check it is already slashed
        require(!proposal.slashed, "Already slashed");
        // Check the optimistic rollup exists
        require(proposal.headerHash != bytes32(0), "Not an existing rollup");
    }

    function _forfeitAndReward(address proposerAddr, address challenger) internal {
        Types.Proposer storage proposer = proposers[proposerAddr];
        // Reward
        uint challengeReward = proposer.stake * 2 / 3;
        payable(challenger).transfer(challengeReward);
        // Forfeit
        proposer.stake = 0;
        proposer.reward = 0;
    }
}
