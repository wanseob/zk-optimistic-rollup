// function commitDeposit() internal {
    //     require(depositStage.queue.length > 0, "Nothing to commit");
    //     commits[depositStage.queue.root()] = DepositCommit(true, depositStage.fee);
    //     delete depositStage;
    // }

    /**
    modifier challenge() {
        // Get proposal hash
        bytes32 opruHash = hashOPRU(
            deposits, withdrawals, outputTreeTransition, nullifierTreeTransition, inclusionRefs,
            nullifiers, outputs, fees, proofs, outputRollUpProofs, nullifierRollUpProofs, proposerAddr
        );
        Types storage opru = proposals[opruHash];
        // Check basic challenge conditions
        checkChallengeCondition(opru);
        // Check type specific conditions
        _;
        // Since the challenge satisfies the given conditions, slash the optimistic rollup proposer
        opru.slashed = true; // Record it as slashed;
        forfeitAndReward(proposerAddr, msg.sender);
    }

    function challengeOutputRollUp(bytes memory serializedRollUp) public challenge(
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
    */