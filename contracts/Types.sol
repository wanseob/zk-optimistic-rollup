pragma solidity >= 0.6.0;

library Types {
    struct Deposit {
        bytes32 note;
        uint256 amount;
        uint256 fee;
    }

    struct Transfer {
        uint8 numberOfInputs;
        uint8 numberOfOutputs;
        uint256 fee;
        bytes32[] inclusionRefs;
        bytes32[] nullifiers;
        bytes32[] outputs;
        uint[8] proof;
    }

    struct Withdrawal {
        uint256 amount;
        uint256 fee;
        address to;
        uint8 numberOfInputs;
        bytes32[] inclusionRefs;
        bytes32[] nullifiers;
        uint[8] proof;
    }

    struct WithdrawalNote {
        uint256 amount;
        uint256 fee;
        address to;
    }

    struct Header {
        bytes32 parentBlock; // genesis block header is keccak256 of the pool address
        bytes32 prevOutputRoot;
        bytes32 prevNullifierRoot;
        bytes32 nextOutputRoot;
        bytes32 nextNullifierRoot;
        bytes32 depositRoot;
        bytes32 transferRoot;
        bytes32 withdrawalRoot;
        uint256 fee;
        address proposer;
    }

    struct Body {
        bytes32[] deposits;
        Transfer[] transfers;
        Withdrawal[] withdrawals;
    }

    struct Block {
        bytes32 id;
        Header header;
        Body body;
    }

    struct Finalization {
        bytes32 blockId;
        Header header;
        bytes32[] deposits;
        WithdrawalNote[] withdrawals;
    }

    struct Proposer {
        uint stake;
        uint reward;
        uint exitAllowance;
    }

    struct Proposal {
        bytes32 headerHash;
        uint challengeDue;
        bool slashed;
    }

    /**
     * @dev Block data will be serialized with the following structure
     *      246 bytes: Header
     *          - 20 bytes: proposer address
     *          - 96 bytes: previous roots(output root + nullifier root + withdrawal root)
     *          - 96 bytes: next roots(output root + nullifier root + withdrawal root)
     *          - 2 bytes: number of transfers
     *          - 32 bytes:  total fee
     *      ? bytes: Array of transfers
     *          Transfer data:
     *              - 1 byte: (n_i) number of intputs
     *              - 1 byte: (n_o) number of outputs
     *              - 1 byte: transfer type
     *              - 32 bytes: transfer fee
     *              - (n_i * 32) bytes: inclusion references
     *              - (n_i * 32) bytes: nullifiers
     *              - (n_o * 32) bytes: outputs
     *              - 256 bytes: zk SNARKs proof
     * @param leftPadding Jump the first n bytes of the calldata which is not the serialized roll up data.
     */
    function blockFromCalldata(uint leftPadding) internal pure returns (Block memory) {
        bytes32 id;
        Header memory header;
        bytes32[] memory deposits;
        Transfer[] memory txs;
        Withdrawal[] memory withdrawals;
        assembly {
            /**
             * @dev It copies `len` of bytes from calldata at `curr_call_cursor` to the memory at `curr_mem_cursor`.
             * and it returns the next calldata cursor and memory cursor to copy and paste. Note that the basic unit
             * of the memory cursor is 32bytes while the basit unit of calldata is 1 byte.
             */
            function cp_calldata_move(curr_mem_cursor, curr_call_cursor, len) -> new_mem_cursor, new_calldata_cursor {
                if lt(len, 0x20) { mstore(curr_mem_cursor, 0) } // initialization with zeroes
                calldatacopy(add(curr_mem_cursor, sub(0x20, len)), curr_call_cursor, len)
                new_calldata_cursor := add(curr_call_cursor, len)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            /**
             * @dev Assign value to the given memory cursor and and returns the next memory cursor 32bytes behind of it.
             */
            function assign_and_move(curr_mem_cursor, value) -> new_mem_cursor {
                mstore(curr_mem_cursor, value)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }

            /** Header */
            // Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            // Skip 0x04 for signature + 0x20 for calldata length + leftPadding
            let calldata_cursor := add(0x24, leftPadding)
            // Define header ptr
            header := memory_cursor
            // Assign values to the allocated memory
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // parentBlock
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevOutputRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextOutputRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // depositRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // transferRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // withdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // fee
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14) // proposer

            /** Body - deposits*/
            // Read the size of the deposit array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_deposits := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of deposits
            deposits := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            // Copy deposit hashes to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))


            /** Body - Transfers */
            // Read the size of the transfer array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_txs := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of transfers
            txs := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_txs)
            // Pointers of each item of the array
            let tx_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_txs))
            // Assign transfer object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_txs) { i := add(i, 1) } {
                // set tx[i]'s ref mem address
                mstore(add(tx_pointers, mul(0x20, i)), memory_cursor)
                // Get number of input
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_i := mload(sub(memory_cursor, 0x20))
                // Get number of output
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_o := mload(sub(memory_cursor, 0x20))
                // Get tx fee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // inclusion refs
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, n_i)
                for { let j := 0 } lt(j, n_i) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
                // nullifiers
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, n_i)
                for { let j := 0 } lt(j, n_i) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
                // outputs
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, n_o)
                for { let j := 0 } lt(j, n_o) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
                // proof
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, 8)
                for { let j := 0 } lt(j, 0x08) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
            }

            /** Body - withdrawals */
            // Read the size of the withdrawal array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_withdrawals := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of withdrawals
            withdrawals := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_withdrawals)
            // Pointers of each item of the array
            let withdrawal_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_withdrawals))
            // Assign Withdrawal object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_withdrawals) { i := add(i, 1) } {
                // set withdrawals[i]'s ref mem address
                mstore(add(withdrawal_pointers, mul(0x20, i)), memory_cursor)
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get fee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get recipient
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
                // Get number of input
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_i := mload(sub(memory_cursor, 0x20))
                // inclusion refs
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, n_i)
                for { let j := 0 } lt(j, n_i) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
                // nullifiers
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, n_i)
                for { let j := 0 } lt(j, n_i) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
                // proof
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, 8)
                for { let j := 0 } lt(j, 0x08) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
            }

            id := keccak256(starting_mem_pos, sub(memory_cursor, starting_mem_pos))
            // Deallocate memory
            mstore(0x40, memory_cursor)
        }
        Body memory body = Body(deposits, txs, withdrawals);
        return Block(id, header, body);
    }

    function finalizationFromCalldata(uint leftPadding) internal pure returns (Finalization memory) {
        bytes32 blockId;
        Header memory header;
        bytes32[] memory deposits;
        WithdrawalNote[] memory withdrawals;
        assembly {
            /**
             * @dev It copies `len` of bytes from calldata at `curr_call_cursor` to the memory at `curr_mem_cursor`.
             * and it returns the next calldata cursor and memory cursor to copy and paste. Note that the basic unit
             * of the memory cursor is 32bytes while the basit unit of calldata is 1 byte.
             */
            function cp_calldata_move(curr_mem_cursor, curr_call_cursor, len) -> new_mem_cursor, new_calldata_cursor {
                if lt(len, 0x20) { mstore(curr_mem_cursor, 0) } // initialization with zeroes
                calldatacopy(add(curr_mem_cursor, sub(0x20, len)), curr_call_cursor, len)
                new_calldata_cursor := add(curr_call_cursor, len)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            /**
             * @dev Assign value to the given memory cursor and and returns the next memory cursor 32bytes behind of it.
             */
            function assign_and_move(curr_mem_cursor, value) -> new_mem_cursor {
                mstore(curr_mem_cursor, value)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }

            /** Header */
            // Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            // Skip 0x04 for signature + 0x20 for calldata length + leftPadding
            let calldata_cursor := add(0x24, leftPadding)
            // Get block id
            blockId := memory_cursor
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // blockId
            // Define header ptr
            header := memory_cursor
            // Assign values to the allocated memory
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // parentBlock
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevOutputRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextOutputRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // depositRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // transferRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // withdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // fee
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14) // proposer

            /** Deposits*/
            // Read the size of the deposit array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_deposits := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of deposits
            deposits := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            // Copy deposit hashes to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))

            /** Withdrawal notes */
            // Read the size of the withdrawal notes array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_withdrawals := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of withdrawals
            withdrawals := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_withdrawals)
            // Pointers of each item of the array
            let withdrawal_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_withdrawals))
            // Assign Withdrawal object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_withdrawals) { i := add(i, 1) } {
                // set withdrawals[i]'s ref mem address
                mstore(add(withdrawal_pointers, mul(0x20, i)), memory_cursor)
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get fee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get recipient
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
            }
            // Deallocate memory
            mstore(0x40, memory_cursor)
        }
        return Finalization(blockId, header, deposits, withdrawals);
    }

    function hash(Header memory header) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                header.parentBlock,
                header.prevOutputRoot,
                header.prevNullifierRoot,
                header.nextOutputRoot,
                header.nextNullifierRoot,
                header.depositRoot,
                header.transferRoot,
                header.withdrawalRoot,
                header.fee,
                header.proposer
            )
        );
    }

    function hash(Transfer memory transfer) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                transfer.numberOfInputs,
                transfer.numberOfOutputs,
                transfer.fee,
                transfer.inclusionRefs,
                transfer.nullifiers,
                transfer.outputs,
                transfer.proof
            )
        );
    }

    function hash(WithdrawalNote memory note) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                note.amount,
                note.fee,
                note.to
            )
        );
    }

    function hash(Withdrawal memory withdrawal) internal pure returns (bytes32) {
        return hash(getNote(withdrawal));
    }

    function getNote(Withdrawal memory withdrawal) internal pure returns (WithdrawalNote memory) {
        return WithdrawalNote(withdrawal.amount, withdrawal.fee, withdrawal.to);
    }

    function root(Transfer[] memory transfers) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](transfers.length);
        for(uint i = 0; i < transfers.length; i++) {
            leaves[i] = hash(transfers[i]);
        }
        return root(leaves);
    }

    function root(Withdrawal[] memory withdrawals) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](withdrawals.length);
        for(uint i = 0; i < withdrawals.length; i++) {
            leaves[i] = hash(withdrawals[i]);
        }
        return root(leaves);
    }


    function root(WithdrawalNote[] memory withdrawalNotes) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](withdrawalNotes.length);
        for(uint i = 0; i < withdrawalNotes.length; i++) {
            leaves[i] = hash(withdrawalNotes[i]);
        }
        return root(leaves);
    }

    function root(bytes32[] memory leaves) public pure returns (bytes32) {
        if(leaves.length == 0) {
            return bytes32(0);
        } else if(leaves.length == 1) {
            return leaves[0];
        }
        bytes32[] memory nodes = new bytes32[]((leaves.length + 1)/2);
        bool hasEmptyLeaf = leaves.length % 2 == 1;

        for (uint i = 0; i < nodes.length; i++) {
            if(hasEmptyLeaf && i == nodes.length - 1) {
                nodes[i] = keccak256(abi.encodePacked(leaves[i*2], bytes32(0)));
            } else {
                nodes[i] = keccak256(abi.encodePacked(leaves[i*2], leaves[i*2+1]));
            }
        }
        return root(nodes);
    }

    // TODO temporal calculation
    function maxChallengeCost(Block memory submission) internal pure returns (uint256 maxCost) {
        uint mtRollUpCost = 0;
        uint smtRollUpCost = 0;
        for(uint i = 0; i < submission.body.transfers.length; i++) {
            Transfer memory transfer = submission.body.transfers[i];
            mtRollUpCost += transfer.numberOfInputs * (16 * 32 * 257);
            smtRollUpCost += transfer.numberOfOutputs * (16 * 32 * 257);
        }
        maxCost = mtRollUpCost > smtRollUpCost ? mtRollUpCost : smtRollUpCost;
    }
}
