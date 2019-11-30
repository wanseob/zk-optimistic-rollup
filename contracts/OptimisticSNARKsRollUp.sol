pragma solidity >=0.4.21 <0.6.0;

contract OptimisticSNARKsRollUp {
    enum ChallengeType { OutputRollUp, NullifierRollUp, SNARKs}

    struct SNARKsTree {
        bytes32 outputTree;
        bytes32 nullifierTree;
    }

    struct SNARKsRollUp {
        bytes32 metadata;
        uint challengeDue;
        bool slashed;
    }

    struct SNARKsRollUpMeta {
        SNARKsTree prev;
        SNARKsTree next;
        address proposer;
        uint fee;
    }

    struct Proposer {
        uint stake;
        uint reward;
        uint exitAllowance;
    }

    mapping(bytes32=>bool) refs;
    bytes32 public outputRoot;
    bytes32 public nullifierRoot;
    bytes32 public withdrawalRoot;

    uint public challengePeriod;
    uint public minimumStake;

    mapping(bytes32=>uint) public unconfirmedDeposits; // leaf : fee
    mapping(address=>Proposer) public proposers;
    mapping(bytes32=>SNARKsRollUp) rollUps;

    // Ideas
    // deposit fee / fixed length deposit array
    // deposit {leaf, fee} array / starting index == stored index /
    // withdrawalTree
    // uint8 type, uint8 in, uint8 out, uing8 withdraw
    // finalizeAndPropose

    constructor(uint _challengePeriod, uint _minimumStake) public {
        challengePeriod = _challengePeriod;
        minimumStake = _minimumStake;
    }

    function register() public payable {
        require(msg.value >= minimumStake, "Should stake more than minimum amount of ETH");
        Proposer storage proposer = proposers[msg.sender];
        proposer.stake += msg.value;
    }

    function deregister() public {
        address payable proposerAddr = msg.sender;
        Proposer storage proposer = proposers[proposerAddr];
        require(proposer.exitAllowance <= block.number, "Still in the challenge period");
        proposerAddr.transfer(proposer.reward + proposer.stake);
        proposer.stake = 0;
        proposer.reward = 0;
    }

    function withdrawReward(uint amount) public {
        address payable proposerAddr = msg.sender;
        Proposer storage proposer = proposers[proposerAddr];
        require(proposer.reward >= amount, "You can't withdraw more than you have");
        proposerAddr.transfer(amount);
        proposer.reward -= amount;
    }

    function propose(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr
    ) public {
        // The message sender address should be same with the proposer address
        require(proposerAddr == msg.sender, "Coordinator account is different with the message sender");
        Proposer storage proposer = proposers[msg.sender];
        // Check permission
        require(proposable(proposer), "Not allowed to propose");
        // Get proposal hash
        bytes32 opruHash = hashOPRU(
            deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
            nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
        );
        // Calculate total fee
        uint fee;
        for(uint i = 0; i < fees.length; i++) {
            fee += fees[i];
            require(fee >= fees[i], "Prevent overflow");
        }
        // Duplicated proposal is not allowed
        require(rollUps[opruHash].metadata == bytes32(0), "Already submitted");
        // Create roll up etadata
        bytes32 metadata = hashMetadata(deposits, outputTreeTransition, nullifierTreeTransition, fee, proposerAddr);
        // Save opru object
        rollUps[opruHash] = SNARKsRollUp(
            metadata,
            block.number + challengePeriod,
            false
        );
        // Update exit allowance period
        proposer.exitAllowance = block.number + challengePeriod;
    }

    function finalize(
        bytes32 opruHash,
        bytes32[] memory deposits,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        address proposerAddr,
        uint fee
    ) public {
        // Retrieve optimistic roll up data
        SNARKsRollUp storage opru = rollUps[opruHash];
        // Should not be slashed
        require(!opru.slashed, "Slashed roll up");
        // Check the validity of metadata
        bytes32 metadata = hashMetadata(deposits, outputTreeTransition, nullifierTreeTransition, fee, proposerAddr);
        require(opru.metadata == metadata, "Metadata does not match with the target");
        // Check the optimistic roll up to finalize is pointing the current root correctly
        require(outputTreeTransition[0] == outputRoot, "Previous output root is not valid");
        require(nullifierTreeTransition[0] == nullifierRoot, "Previous nullifier root is not valid");
        for(uint i = 0; i < deposits.length; i++) {
            confirmDeposit(deposits[i]);
        }
        // Update the current root
        outputRoot = outputTreeTransition[1];
        nullifierRoot = nullifierTreeTransition[1];
        // Give fee
        Proposer storage proposer = proposers[proposerAddr];
        proposer.reward += fee;
    }

    modifier challenge(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr
    ) {
        // Get proposal hash
        bytes32 opruHash = hashOPRU(
            deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
            nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
        );
        SNARKsRollUp storage opru = rollUps[opruHash];
        // Check basic challenge conditions
        checkChallengeCondition(opru);
        // Check type specific conditions
        _;
        // Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        opru.slashed = true; // Record it as slashed;
        forfeitAndReward(proposerAddr, msg.sender);
    }

    function challengeOutputRollUp(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr
    ) public challenge(
        deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
        nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
    ) {
        bytes32[] memory leaves = new bytes32[](deposits.length + outputs.length*2);
        for(uint i = 0; i < deposits.length; i++) {
            leaves[i] = deposits[i];
        }
        for(uint j = 0; j < deposits.length; j++) {
            leaves[deposits.length + 2*j] = outputs[j][0];
            leaves[deposits.length + 2*j + 1] = outputs[j][1];
        }
        bytes32 nextRoot = outputRollUp(outputTreeTransition[0], leaves, outputRollUpProofs);
        require(nextRoot != outputTreeTransition[1], "Output roll up is valid.");
    }

    function challengeInclusionRefs(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr
    ) public challenge(
        deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
        nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
    ) {
        bool success = false;
        for(uint i = 0; i < inclusionRefs.length; i++) {
            if(!refs[inclusionRefs[i][0]] || !refs[inclusionRefs[i][1]]) {
                success = true;
                break;
            }
        }
        require(success, "Inclusion refs are valid.");
    }

    function challengeNullifierRollUp(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr
    ) public challenge(
        deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
        nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
    ) {
        bytes32[] memory leaves = new bytes32[](nullifiers.length*2);
        for(uint i = 0; i < nullifiers.length; i++) {
            leaves[2*i] = nullifiers[i][0];
            leaves[2*i + 1] = nullifiers[i][1];
        }
        bytes32 nextRoot = nullifierRollUp(nullifierTreeTransition[0], leaves, nullifierRollUpProofs);
        require(nextRoot != nullifierTreeTransition[1], "Nullifier roll up is valid.");
    }

    function challengeSNARKs(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposerAddr,
        uint leafIndex
    ) public challenge(
        deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
        nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
    ) {
        uint[] memory inputs = new uint[](7);
        inputs[0] = fees[leafIndex];
        inputs[1] = uint(inclusionRefs[leafIndex][0]);
        inputs[2] = uint(inclusionRefs[leafIndex][1]);
        inputs[3] = uint(nullifiers[leafIndex][0]);
        inputs[4] = uint(nullifiers[leafIndex][1]);
        inputs[5] = uint(outputs[leafIndex][0]);
        inputs[6] = uint(outputs[leafIndex][1]);
        require(
            !verifySNARKs(
                [proofs[leafIndex][0], proofs[leafIndex][1]],
                [
                    [proofs[leafIndex][2], proofs[leafIndex][3]],
                    [proofs[leafIndex][4], proofs[leafIndex][5]]
                ],
                [proofs[leafIndex][6], proofs[leafIndex][7]],
                inputs
            ),
            "Valid SNARKs transaction"
        );
    }

    function proposable(address proposerAddr) public view returns (bool) {
        return proposable(proposers[proposerAddr]);
    }

    function proposable(Proposer memory  proposer) internal view returns (bool) {
        // You can add more consensus logic here
        if(proposer.stake <= minimumStake) {
            return false;
        } else {
            return true;
        }
    }

    function hashOPRU(
        bytes32[] memory deposits,
        bytes32[] memory withdrawals,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        bytes32[2][] memory inclusionRefs,
        bytes32[2][] memory nullifiers,
        bytes32[2][] memory outputs,
        uint[] memory fees,
        uint[8][] memory proofs,
        bytes32[256][] memory outputRollUpProofs,
        bytes32[256][] memory nullifierRollUpProofs,
        address proposer
    ) public pure returns (bytes32) {
        bytes32 opruHash = keccak256(
            abi.encodePacked(
                deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
                nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposer
            )
        );
        return opruHash;
    }

    function hashMetadata(
        bytes32[] memory deposits,
        bytes32[2] memory outputTreeTransition,
        bytes32[2] memory nullifierTreeTransition,
        uint fee,
        address proposer
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(deposits, outputTreeTransition, nullifierTreeTransition, proposer, fee));
    }

    function checkChallengeCondition(SNARKsRollUp storage opru) internal view {
        // Check the optimistic roll up is in the challenge period
        require(opru.challengeDue > block.number, "You missed the challenge period");
        // Check it is already slashed
        require(!opru.slashed, "Already slashed");
        // Check the optimistic rollup exists
        require(opru.metadata != bytes32(0), "Not an existing rollup");
    }

    function confirmDeposit(bytes32 deposit) internal {
        // Unconfirmed deposit should exist
        require(unconfirmedDeposits[deposit] > 0, "Deposit does not exist");
        // Remove the unconfirmed deposit
        address payable feeTo = msg.sender;
        feeTo.transfer(unconfirmedDeposits[deposit]);
        unconfirmedDeposits[deposit] = 0;
    }

    function forfeitAndReward(address proposerAddr, address payable challenger) internal {
        Proposer storage proposer = proposers[proposerAddr];
        // Reward
        uint challengeReward = proposer.stake * 2 / 3;
        challenger.transfer(challengeReward);
        // Forfeit
        proposer.stake = 0;
        proposer.reward = 0;
    }

    function outputRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function nullifierRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function verifySNARKs(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[] memory input) public view returns (bool);
}
