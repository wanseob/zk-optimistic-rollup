pragma solidity >=0.4.21 <0.6.0;

library SNARKsRollUp {
    struct Transaction {
        uint8 numberOfInputs;
        uint8 numberOfOutputs;
        uint8 txType;
        uint fee;
        bytes32[] inclusionRefs;
        bytes32[] nullifiers;
        bytes32[] outputs;
        uint[8] proofs;
    }

    struct Metadata {
        address proposer;
        bytes32 prevOutputRoot;
        bytes32 prevNullifierRoot;
        bytes32 prevWithdrawalRoot;
        bytes32 nextOutputRoot;
        bytes32 nextNullifierRoot;
        bytes32 nextWithdrawalRoot;
        uint16 numberOfTxs;
        uint totalFee;
    }

    struct RollUp {
        bytes32 id;
        Metadata metadata;
        Transaction[] txs;
        bytes32 extra;
    }

    function calldataToRollUp() internal pure returns (RollUp memory rollUp) {
        bytes32 id;
        Metadata memory metadata;
        Transaction[] memory txs;
        bytes32 extra;
        assembly {
            // Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            // Define metadata ptr
            metadata := memory_cursor
            let calldata_cursor := 0x44 // 0x04 for signature + 0x20 for length

            function cp_calldata_move(curr_mem_cursor, curr_call_cursor, len) -> new_mem_cursor, new_calldata_cursor {
                if lt(len, 0x20) { mstore(curr_mem_cursor, 0) } // TODO should be tested, init with zeroes
                calldatacopy(add(curr_mem_cursor, sub(0x20, len)), curr_call_cursor, len)
                new_calldata_cursor := add(curr_call_cursor, len)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            function assign_and_move(curr_mem_cursor, value) -> new_mem_cursor {
                mstore(curr_mem_cursor, value)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            // Metadata
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_txs := mload(sub(memory_cursor, 0x20))
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)

            // Transactions array initialization
            // 1. Set length
            txs := memory_cursor
            memory_cursor := assign_and_move(memory_cursor, num_of_txs)
            // 2. Leave space to point struct items
            let pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_txs))
            // 3. Assign values to each item
            for { let i := 0 } lt(i, num_of_txs) { i := add(i, 1) } {
                // set tx[i]'s ref mem address
                mstore(add(pointers, mul(0x20, i)), memory_cursor)
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_i := mload(sub(memory_cursor, 0x20))
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_o := mload(sub(memory_cursor, 0x20))
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
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
                // proofs
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, 8)
                for { let j := 0 } lt(j, 0x08) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
            }
            id := keccak256(starting_mem_pos, sub(memory_cursor, starting_mem_pos))
            // Extra data
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            extra := mload(sub(memory_cursor, 0x20))
            // Deallocate memory
            mstore(0x40, memory_cursor)
        }
        return RollUp(id, metadata, txs, extra);
    }
}
