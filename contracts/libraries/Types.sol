pragma solidity >= 0.6.0;
enum TxType { Deposit, Withdrawal, Migration, Transfer, Trade, Burn }

struct Blockchain {
    bytes32 latest;
    /** For inclusion reference */
    mapping(bytes32=>bytes32) parentOf; // childBlockHash=>parentBlockHash
    mapping(bytes32=>uint256) utxoRootOf; // header => utxoRoot
    mapping(uint256=>bool) finalizedUTXOs; // all finalized utxoRoots
    /** For coordinating */
    mapping(address=>Proposer) proposers;
    mapping(bytes32=>Proposal) proposals;
    /** For deposit */
    MassDeposit[] depositQueue;
    /** For withdrawal */
    Withdrawable[] withdrawables; /// 0: daily snapshot of the latest withdrawable tree
    uint256 snapshotTimestamp;
    mapping(bytes32=>bool) withdrawn;
    /** For migrations */
    MassMigration[] migrations;
}

struct MassDeposit {
    bytes32 merged;
    uint256 amount;
    uint256 fee;
    uint256 length;
    bool committed;
}

struct MassMigration {
    address destination;
    uint256 amount;
    uint256 migrationFee;
    bytes32 mergedLeaves;
    uint256 length;
}

struct Withdrawable {
    /// Merkle tree of Withdrawable notes
    bytes32 root;
    uint index;
}

// struct Transfer {
//     uint8 numberOfInputs;
//     uint8 numberOfOutputs;
//     uint256 fee;
//     uint256[] inclusionRefs;
//     bytes32[] nullifiers;
//     uint256[] outputs;
//     uint256[8] proof;
// }

/** Transaction inside the layer 2 */
struct L2Tx {
    uint8 txType; // l2Tx / trade / burn
    uint8 numberOfInputs;
    uint8 numberOfOutputs;
    uint256 fee;
    uint256[] inclusionRefs;
    bytes32[] nullifiers;
    uint256[] outputs;
    uint256[8] proof;
}

/** Transactions between the layer 1 and layer 2 */
struct Deposit {
    uint256 amount;
    uint256 salt;
    uint[2] pubKey;
    uint256 nft;
}
struct Withdrawal {
    uint8 numberOfInputs;
    uint256 amount;
    uint256 fee;
    address to;
    bytes32 nft;
    uint256[] inclusionRefs;
    bytes32[] nullifiers;
    uint256[8] proof;
}

struct Migration {
    uint8 numberOfInputs;
    uint256 leaf; /// amount, salt, pubkey[2]
    address destination;
    uint256 amount;
    uint256 fee;
    uint256 migrationFee; /// migration executor will take this
    uint256[] inclusionRefs;
    bytes32[] nullifiers;
    uint256[8] proof;
}

struct Header {
    bytes32 parentBlock;
    /** UTXO roll up  */
    uint256 prevUTXORoot;
    uint256 prevUTXOIndex;
    uint256 nextUTXORoot;
    uint256 nextUTXOIndex;

    /** Nullifier roll up  */
    bytes32 prevNullifierRoot;
    bytes32 nextNullifierRoot;

    /** Withdrawal roll up  */
    bytes32 prevWithdrawalRoot;
    uint256 prevWithdrawalIndex;
    bytes32 nextWithdrawalRoot;
    uint256 nextWithdrawalIndex;

    /** Transactions */
    bytes32 depositRoot;
    bytes32 l2TxRoot;
    bytes32 withdrawalRoot;
    bytes32 migrationRoot;
    bytes32 tradesRoot;

    /** Etc */
    uint256 fee;
    bytes32 metadata;
    address proposer;
}

struct Body {
    uint[] depositIds;
    L2Tx[] l2Txs;
    Withdrawal[] withdrawals;
    Migration[] migrations;
}

struct Block {
    bytes32 id;
    Header header;
    Body body;
}

struct Finalization {
    bytes32 blockId;
    Header header;
    uint[] depositIds;
    MassMigration[] migrations;
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

struct Challenge {
    bool slash;
    bytes32 proposalId;
    address proposer;
    string message;
}

library Types {
    function init(Blockchain storage chain, bytes32 genesis) internal {
        chain.latest = genesis;
        chain.withdrawables.push(); /// withdrawables[0]: daily snapshot
        chain.withdrawables.push(); /// withdrawables[0]: initial withdrawable tree
    }

    /**
     * @dev Block data will be serialized with the following structure
     *      https://github.com/wilsonbeam/zk-optimistic-rollup/wiki/Serialization
     * @param paramIndex The index of the block calldata parameter in the external function
     */
    function blockFromCalldataAt(uint paramIndex) internal pure returns (Block memory) {
        /// 4 means the length of the function signature in the calldata
        uint startsFrom = 4 + abi.decode(msg.data[4 + 32*paramIndex:4 + 32*(paramIndex+1)], (uint));
        bytes32 id;
        Header memory header;
        uint[] memory depositIds;
        L2Tx[] memory l2Txs;
        Withdrawal[] memory withdrawals;
        Migration[] memory migrations;
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
            depositIds := memory_cursor
            /// Set length of the array
            memory_cursor := assign_and_move(memory_cursor, num_of_deposits)
            /// Copy deposit ids to the array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, mul(num_of_deposits, 0x20))


            /** Body - L2Txs */
            // Read the size of the l2Tx array
            memory_cursor, calldata_cursor := cp_calldata_move(memory_cursor, calldata_cursor, 0x02)
            let num_of_txs := mload(sub(memory_cursor, 0x20))
            // Allocate memory for the array of l2Txs
            l2Txs := memory_cursor
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
            migrations := memory_cursor
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

            id := keccak256(starting_mem_pos, sub(memory_cursor, starting_mem_pos))
            // Deallocate memory
            mstore(0x40, memory_cursor)
        }
        Body memory body = Body(depositIds, l2Txs, withdrawals, migrations);
        return Block(id, header, body);
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
        return Finalization(blockId, header, depositIds, migrations);
    }

    function hash(Header memory header) internal pure returns (bytes32) {
        bytes32 headerHash;
        uint HEADER_LENGTH = 17 * 32 + 20;
        assembly {
            headerHash := keccak256(header, HEADER_LENGTH)
        }
        return headerHash;
    }

    function hash(L2Tx memory l2Tx) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                l2Tx.numberOfInputs,
                l2Tx.numberOfOutputs,
                l2Tx.fee,
                l2Tx.inclusionRefs,
                l2Tx.nullifiers,
                l2Tx.outputs,
                l2Tx.proof
            )
        );
    }

    function hash(Withdrawal memory withdrawal) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                withdrawal.amount,
                withdrawal.fee,
                withdrawal.to,
                withdrawal.numberOfInputs,
                withdrawal.inclusionRefs,
                withdrawal.nullifiers,
                withdrawal.proof
            )
        );
    }
    
    function hash(MassMigration memory massMigration) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                massMigration.destination,
                massMigration.amount,
                massMigration.migrationFee,
                massMigration.mergedLeaves
            )
        );
    }

    function root(L2Tx[] memory l2Txs) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](l2Txs.length);
        for(uint i = 0; i < l2Txs.length; i++) {
            leaves[i] = hash(l2Txs[i]);
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

    function root(Migration[] memory migrations) internal pure returns (bytes32) {
        return root(toMassMigration(migrations));
    }

    function toMassMigration(Migration[] memory migrations) internal pure returns (MassMigration[] memory) {
        MassMigration[] memory massMigrations = new MassMigration[](migrations.length);
        MassMigration memory toMerge;
        Migration memory migration;
        uint numOfDestination = 0;
        for(uint i = 0; i < migrations.length; i++) {
            bool found;
            migration = migrations[i];
            for(uint j = 0; j < numOfDestination; j++) {
                if(massMigrations[j].destination == migration.destination) {
                    toMerge = massMigrations[j];
                    found = true;
                }
                if(found) break;
            }
            if(!found) {
                toMerge = massMigrations[++numOfDestination];
            }
            toMerge.amount += migration.amount;
            toMerge.migrationFee += migration.migrationFee;
            toMerge.mergedLeaves = keccak256(
                abi.encodePacked(toMerge.mergedLeaves, migration.leaf)
            );
            toMerge.length++;
        }
        MassMigration[] memory packed = new MassMigration[](numOfDestination);
        for(uint i = 0; i < numOfDestination; i++) {
            packed[i] = massMigrations[i];
        }
        return packed;
    }

    function root(MassMigration[] memory massMigrations) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](massMigrations.length);
        for(uint i = 0; i < massMigrations.length; i++) {
            leaves[i] = hash(massMigrations[i]);
        }
        return root(leaves);
    }

    function root(bytes32[] memory leaves) internal pure returns (bytes32) {
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

    function root(uint[] memory leaves) internal pure returns (bytes32) {
        bytes32[] memory converted;
        assembly {
            converted := leaves
        }
        return root(converted);
    }

    // TODO temporal calculation
    function maxChallengeCost(Block memory submission) internal pure returns (uint256 maxCost) {
        uint mtRollUpCost = 0;
        uint smtRollUpCost = 0;
        for(uint i = 0; i < submission.body.l2Txs.length; i++) {
            L2Tx memory l2Tx = submission.body.l2Txs[i];
            mtRollUpCost += l2Tx.numberOfInputs * (16 * 32 * 257);
            smtRollUpCost += l2Tx.numberOfOutputs * (16 * 32 * 257);
        }
        maxCost = mtRollUpCost > smtRollUpCost ? mtRollUpCost : smtRollUpCost;
    }

    function getSNARKsSignature(
        TxType txType,
        uint8 numberOfInputs,
        uint8 numberOfOutputs
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(txType, numberOfInputs, numberOfOutputs));
    }
}
