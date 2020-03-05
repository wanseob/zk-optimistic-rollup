pragma solidity >= 0.6.0;

import { Header, Body, Transaction, MassDeposit, MassMigration, Block, Finalization } from "./Types.sol";

library Deserializer {
    /**
     * @dev Block data will be serialized with the following structure
     *      https://github.com/wilsonbeam/zk-optimistic-rollup/wiki/Serialization
     * @param paramIndex The index of the block calldata parameter in the external function
     */
    function blockFromCalldataAt(uint paramIndex) internal pure returns (Block memory) {
        /// 4 means the length of the function signature in the calldata
        uint startsFrom = 4 + abi.decode(msg.data[4 + 32*paramIndex:4 + 32*(paramIndex+1)], (uint));
        Header memory header;
        // uint[] memory massDepositIds;
        // MassWithdrawal[] memory massWithdrawals;
        // Transaction[] memory transactions;
        // L2Tx[] memory l2Txs;
        // Withdrawal[] memory withdrawals;
        // Migration[] memory migrations;
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

            /// Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            /// Skip 0x04 for signature + 0x20 for calldata length + startsFrom
            let calldata_cursor := startsFrom

            /** Header */
            /// Define header ptr
            header := memory_cursor
            /// Assign values to the allocated memory
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // parentBlock
            /// utxo roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXOIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXOIndex
            /// nullifier roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextNullifierRoot
            /// withdrawal roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalIndex
            /// transaction result
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // depositRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // l2TxRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // withdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // migrationRoot
            /// Etc
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // fee
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // metadata
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14) // proposer

            /** Body - deposits*/
            /// Read the size of the deposit array (maximum 1024)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_deposits := mload(sub(memory_cursor, 0x20))
            /// Allocate memory for the array of deposits
            // depositIds := memory_cursor
            /// Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            /// Copy deposit ids to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))


            /** Body - L2Txs */
            // Read the size of the l2Tx array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_txs := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of l2Txs
            // l2Txs := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_txs)
            // Pointers of each item of the array
            let tx_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_txs))
            // Assign l2Tx object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_txs) { i := add(i, 1) } {
                // set tx[i]'s ref mem address
                mstore(add(tx_pointers, mul(0x20, i)), memory_cursor)
                // Get tx type
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
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
            // withdrawals := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_withdrawals)
            // Pointers of each item of the array
            let withdrawal_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_withdrawals))
            // Assign Withdrawal object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_withdrawals) { i := add(i, 1) } {
                // set withdrawals[i]'s ref mem address
                mstore(add(withdrawal_pointers, mul(0x20, i)), memory_cursor)
                // Get number of input
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_i := mload(sub(memory_cursor, 0x20))
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get fee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get recipient
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
                // Get nft
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
                // proof
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, 8)
                for { let j := 0 } lt(j, 0x08) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
            }
            
            /** Body - migrations */
            // Read the size of the migrations array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_migrations := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of migrations
            // migrations := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_migrations)
            // Pointers of each item of the array
            let migration_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_migrations))
            // Assign Migration object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_migrations) { i := add(i, 1) } {
                // set migrations[i]'s ref mem address
                mstore(add(migration_pointers, mul(0x20, i)), memory_cursor)
                // Get number of input
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x01)
                let n_i := mload(sub(memory_cursor, 0x20))
                // Get the leaf that is the resulf of poseidon(amount, salt, pubKey[2])
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get destination
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get fee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get migrationFee
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
                // proof
                memory_cursor := assign_and_move(memory_cursor, add(memory_cursor, 0x20))
                memory_cursor := assign_and_move(memory_cursor, 8)
                for { let j := 0 } lt(j, 0x08) { j := add(j, 1) } {
                    memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                }
            }

            // id := keccak256(starting_mem_pos, sub(memory_cursor, starting_mem_pos))
            // Deallocate memory
            mstore(0x40, memory_cursor)
        }
        // Body memory body = Body(depositIds, l2Txs, withdrawals, migrations);
        // return Block(id, header, body);
    }

    /**
     * @dev Block data will be serialized with the following structure
     *      https://github.com/wilsonbeam/zk-optimistic-rollup/wiki/Serialization
     * @param paramIndex The index of the block calldata parameter in the external function
     */
    function finalizationFromCalldataAt(uint paramIndex) internal pure returns (Finalization memory) {
        /// 4 means the length of the function signature in the calldata
        uint startsFrom = 4 + abi.decode(msg.data[4 + 32*paramIndex : 4 + 32*(paramIndex+1)], (uint));
        bytes32 blockId;
        Header memory header;
        uint[] memory depositIds;
        MassMigration[] memory migrations;
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

            /// Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            let calldata_cursor := startsFrom
            /** Get blockId */
            blockId := memory_cursor
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // blockId

            /** Header */
            /// Define header ptr
            header := memory_cursor
            /// Assign values to the allocated memory
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // parentBlock
            /// utxo roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXOIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXOIndex
            /// nullifier roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextNullifierRoot
            /// withdrawal roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalIndex
            /// transaction result
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // depositRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // l2TxRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // withdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // fee
            /// Other metadata
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14) // proposer
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // metadata

            /** Get depositIds */
            /// Read the size of the deposit array (maximum 1024)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_deposits := mload(sub(memory_cursor, 0x20))
            /// Allocate memory for the array of deposits
            depositIds := memory_cursor
            /// Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            /// Copy deposit ids to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))

            /** Get mass migrations */
            // Read the size of the migrations array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_migrations := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of migrations
            migrations := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_migrations)
            // Pointers of each item of the array
            let migration_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_migrations))
            // Assign MassMigration object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_migrations) { i := add(i, 1) } {
                // set migrations[i]'s ref mem address
                mstore(add(migration_pointers, mul(0x20, i)), memory_cursor)
                // Get destination
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get migrationFee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get mergedLeaves
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get number of total merged leaves
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            }

            /// Deallocate memory
            mstore(0x40, memory_cursor)
        }
        // return Finalization(blockId, header, depositIds, migrations);
    }

    /**
     * @dev Block data will be serialized with the following structure
     *      https://github.com/wilsonbeam/zk-optimistic-rollup/wiki/Serialization
     * @param paramIndex The index of the block calldata parameter in the external function
     */
    function massMigrationFromCalldataAt(uint paramIndex) internal pure returns (MassMigration memory) {
        /// 4 means the length of the function signature in the calldata
        uint startsFrom = 4 + abi.decode(msg.data[4 + 32*paramIndex : 4 + 32*(paramIndex+1)], (uint));
        bytes32 blockId;
        Header memory header;
        uint[] memory depositIds;
        MassMigration[] memory migrations;
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

            /// Allocate memory
            let starting_mem_pos := mload(0x40)
            let memory_cursor := starting_mem_pos
            let calldata_cursor := startsFrom
            /** Get blockId */
            blockId := memory_cursor
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // blockId

            /** Header */
            /// Define header ptr
            header := memory_cursor
            /// Assign values to the allocated memory
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // parentBlock
            /// utxo roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevUTXOIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXORoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextUTXOIndex
            /// nullifier roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevNullifierRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextNullifierRoot
            /// withdrawal roll up
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // prevWithdrawalIndex
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // nextWithdrawalIndex
            /// transaction result
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // depositRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // l2TxRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // withdrawalRoot
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // fee
            /// Other metadata
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14) // proposer
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20) // metadata

            /** Get depositIds */
            /// Read the size of the deposit array (maximum 1024)
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_deposits := mload(sub(memory_cursor, 0x20))
            /// Allocate memory for the array of deposits
            depositIds := memory_cursor
            /// Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            /// Copy deposit ids to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))

            /** Get mass migrations */
            // Read the size of the migrations array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_migrations := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of migrations
            migrations := memory_cursor
            // Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_migrations)
            // Pointers of each item of the array
            let migration_pointers := memory_cursor
            memory_cursor := add(memory_cursor, mul(0x20, num_of_migrations))
            // Assign MassMigration object to the memory address and let the pointer indicate the position
            for { let i := 0 } lt(i, num_of_migrations) { i := add(i, 1) } {
                // set migrations[i]'s ref mem address
                mstore(add(migration_pointers, mul(0x20, i)), memory_cursor)
                // Get destination
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x14)
                // Get amount
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get migrationFee
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get mergedLeaves
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
                // Get number of total merged leaves
                memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x20)
            }

            /// Deallocate memory
            mstore(0x40, memory_cursor)
        }
        // return Finalization(blockId, header, depositIds, migrations);
    }
}
