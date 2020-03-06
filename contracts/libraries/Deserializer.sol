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
        uint start = 4 + abi.decode(msg.data[4 + 32*paramIndex:4 + 32*(paramIndex+1)], (uint));
        Block memory _block;
        assembly {
            // bytes.length
            let starting_mem_pos := mload(0x40)
            let mem_pos := starting_mem_pos
            calldatacopy(mem_pos, start, 0x20)
            let data_len := mload(mem_pos)
            mem_pos := add(mem_pos, 0x20)

            // Header
            let p_header := mem_pos
            let cp := add(start, 0x20)
            let header_len := 0x214 // 0x14 + 16 * 0x20;
            mstore(p_header, 0) // put zeroes into the first 32bytes
            calldatacopy(add(p_header, 0x0c), cp, header_len)
            mem_pos := add(mem_pos, mul(17, 0x20))
            cp := add(cp, header_len) // skip bytes.length + header.length

            function copy_and_move(curr_mem_cursor, curr_call_cursor) -> new_mem_cursor, new_calldata_cursor {
                calldatacopy(curr_mem_cursor, curr_call_cursor, 0x20)
                new_calldata_cursor := add(curr_call_cursor, 0x20)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            function partial_copy_and_move(curr_mem_cursor, curr_call_cursor, len) -> new_mem_cursor, new_calldata_cursor { 
                mstore(curr_mem_cursor, 0) // initialization with zeroes
                calldatacopy(add(curr_mem_cursor, sub(0x20, len)), curr_call_cursor, len)
                new_calldata_cursor := add(curr_call_cursor, len)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }
            function assign_and_move(curr_mem_cursor, value) -> new_mem_cursor {
                mstore(curr_mem_cursor, value)
                new_mem_cursor := add(curr_mem_cursor, 0x20)
            }

            // Body
            let p_txs := mem_pos
            mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x02) //txs.len
            let txs_len := mload(p_txs)
            let p_txs_0 := mem_pos
            // reserve slots for p_tx_i
            mem_pos := add(mem_pos, mul(txs_len, 0x20))
            for { let i := 0 } lt(i, txs_len) { i := add(i, 1) } {
                /// Get items of Inflow[] array
                let p_tx_i_inflow := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // inflow len
                let inflow_len := mload(p_tx_i_inflow)
                let p_tx_i_inflow_0 := mem_pos
                // reserve slots for p_tx_i_inflow_j
                mem_pos := add(mem_pos, mul(inflow_len, 0x20))
                for { let j := 0 } lt(j, inflow_len) { j := add(j, 1) } {
                    // init inflow[j]
                    let p_tx_i_inflow_j := mem_pos
                    mem_pos, cp := copy_and_move(mem_pos, cp) // root
                    mem_pos, cp := copy_and_move(mem_pos, cp) // nullifier
                    mstore(add(p_tx_i_inflow_0, mul(0x20, j)), p_tx_i_inflow_j)
                }
                /// Get items of Outflow[] array
                let p_tx_i_outflow := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // outflow len
                let outflow_len := mload(p_tx_i_outflow)
                let p_tx_i_outflow_0 := mem_pos
                // reserve slots for p_tx_i_inflow_j
                mem_pos := add(mem_pos, mul(outflow_len, 0x20))
                for { let j := 0 } lt(j, outflow_len) { j := add(j, 1) } {
                    let p_tx_i_outflow_j_note := mem_pos
                    mem_pos, cp := copy_and_move(mem_pos, cp) // note
                    mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // has data
                    // init outflow[j].publicData
                    switch mload(sub(mem_pos, 0x20))
                    case 0
                    {
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                    }
                    default
                    {
                        mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x14) // to
                        mem_pos, cp := copy_and_move(mem_pos, cp) // eth
                        mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x14) // token
                        mem_pos, cp := copy_and_move(mem_pos, cp) // amount
                        mem_pos, cp := copy_and_move(mem_pos, cp) // nft
                        mem_pos, cp := copy_and_move(mem_pos, cp) // fee
                    }
                    // init outflow[j]
                    let p_tx_i_outflow_j := mem_pos
                    mem_pos := assign_and_move(mem_pos, mload(p_tx_i_outflow_j_note))
                    mem_pos := assign_and_move(mem_pos, mload(add(p_tx_i_outflow_j_note, 0x40)))
                    mstore(add(p_tx_i_outflow_0, mul(0x20, j)), p_tx_i_outflow_j)
                }
                // AtomicSwap
                let p_tx_i_swap_existence := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // swap existence
                let p_tx_i_swap := mem_pos
                switch mload(p_tx_i_swap_existence)
                case 0 {
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                        mem_pos := assign_and_move(mem_pos, 0)
                }
                default
                {
                        mem_pos, cp := copy_and_move(mem_pos, cp) // binder[0]
                        mem_pos, cp := copy_and_move(mem_pos, cp) // binder[1]
                        mem_pos, cp := copy_and_move(mem_pos, cp) // counterpart[0]
                        mem_pos, cp := copy_and_move(mem_pos, cp) // counterpart[1]
                }
                // SNARK proof
                let p_tx_i_proof_a := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // a.X
                mem_pos, cp := copy_and_move(mem_pos, cp) // a.Y
                let p_tx_i_proof_b := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // a.X[0]
                mem_pos, cp := copy_and_move(mem_pos, cp) // a.X[1]
                mem_pos, cp := copy_and_move(mem_pos, cp) // b.Y[0]
                mem_pos, cp := copy_and_move(mem_pos, cp) // b.Y[1]
                let p_tx_i_proof_c := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // c.X
                mem_pos, cp := copy_and_move(mem_pos, cp) // c.Y
                // tx[i].proof = Proof(a, b, c)
                let p_tx_i_proof := mem_pos
                mem_pos := assign_and_move(mem_pos, p_tx_i_proof_a)
                mem_pos := assign_and_move(mem_pos, p_tx_i_proof_b)
                mem_pos := assign_and_move(mem_pos, p_tx_i_proof_c)
                // tx[i] = Transaction(,,,,)
                let p_tx_i := mem_pos
                mem_pos := assign_and_move(mem_pos, p_tx_i_inflow)
                mem_pos := assign_and_move(mem_pos, p_tx_i_outflow)
                mem_pos := assign_and_move(mem_pos, p_tx_i_swap)
                mem_pos := assign_and_move(mem_pos, p_tx_i_proof)
                mem_pos, cp := copy_and_move(mem_pos, cp) // copy fee
                mstore(add(p_txs_0, mul(0x20, i)), p_tx_i)
            }

            let p_mass_deposits := mem_pos
            mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x02) //massDeposits.len
            let mass_deposits_len := mload(p_mass_deposits)
            let p_mass_deposit_0 := mem_pos
            // reserve slots for p_mass_deposit_i
            mem_pos := add(mem_pos, mul(mass_deposits_len, 0x20))
            for { let i := 0 } lt(i, mass_deposits_len) { i := add(i, 1) } {
                let p_mass_deposit_i := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // merged
                mem_pos, cp := copy_and_move(mem_pos, cp) // fee
                mstore(add(p_mass_deposit_0, mul(0x20, i)), p_mass_deposit_i)
            }

            let p_mass_migrations := mem_pos
            mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x02) //massDeposits.len
            let mass_migrations_len := mload(p_mass_migrations)
            let p_mass_migration_0 := mem_pos
            // reserve slots for p_mass_migration_i
            mem_pos := add(mem_pos, mul(mass_migrations_len, 0x20))
            for { let i := 0 } lt(i, mass_migrations_len) { i := add(i, 1) } {
                let p_mass_migration_i_dest := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x14) // dest
                let p_mass_migration_i_eth := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // eth
                let p_mass_migration_i_mass_deposit := mem_pos
                mem_pos, cp := copy_and_move(mem_pos, cp) // migration_i_mass_deposit_merged
                mem_pos, cp := copy_and_move(mem_pos, cp) // migration_i_mass_deposit_fee


                /// Get items of ERC20Migration[] array
                let p_mm_i_erc20 := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // erc20 migration len
                let mm_i_erc20_len := mload(p_mm_i_erc20)
                let p_mm_i_erc20_0 := mem_pos
                // reserve slots for p_tx_i_inflow_j
                mem_pos := add(mem_pos, mul(mm_i_erc20_len, 0x20))
                for { let j := 0 } lt(j, mm_i_erc20_len) { j := add(j, 1) } {
                    // init ERC20Migration[j]
                    let p_mm_i_erc20_j := mem_pos
                    mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x14) // token addr
                    mem_pos, cp := copy_and_move(mem_pos, cp) // amount
                    mstore(add(p_mm_i_erc20_0, mul(0x20, j)), p_mm_i_erc20_j)
                }

                /// Get items of ERC721Migration[] array
                let p_mm_i_erc721 := mem_pos
                mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // erc721 migration len
                let mm_i_erc721_len := mload(p_mm_i_erc721)
                let p_mm_i_erc721_0 := mem_pos
                // reserve slots for p_tx_i_inflow_j
                mem_pos := add(mem_pos, mul(mm_i_erc721_len, 0x20))
                for { let j := 0 } lt(j, mm_i_erc721_len) { j := add(j, 1) } {
                    // init ERC721Migration[j]
                    let p_mm_i_erc721_j_addr := mem_pos
                    mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x14) // token addr
                    let p_mm_i_erc721_j_nft := mem_pos
                    mem_pos, cp := partial_copy_and_move(mem_pos, cp, 0x01) // nft length
                    for { let k := 0 } lt(k, mload(p_mm_i_erc721_j_nft)) { k := add(k, 1) } {
                        mem_pos, cp := copy_and_move(mem_pos, cp) // nft[k]
                    }
                    let p_mm_i_erc721_j := mem_pos
                    mem_pos := assign_and_move(mem_pos, mload(p_mm_i_erc721_j_addr))
                    mem_pos := assign_and_move(mem_pos, p_mm_i_erc721_j_nft)
                    mstore(add(p_mm_i_erc721_0, mul(0x20, j)), p_mm_i_erc721_j)
                }
                let p_mass_migration_i := mem_pos
                mem_pos := assign_and_move(mem_pos, mload(p_mass_migration_i_dest))
                mem_pos := assign_and_move(mem_pos, mload(p_mass_migration_i_eth))
                mem_pos := assign_and_move(mem_pos, p_mass_migration_i_mass_deposit)
                mem_pos := assign_and_move(mem_pos, p_mm_i_erc20)
                mem_pos := assign_and_move(mem_pos, p_mm_i_erc721)
                mstore(add(p_mass_migration_0, mul(0x20, i)), p_mass_migration_i)
            }
            let p_body := mem_pos
            mem_pos := assign_and_move(mem_pos, p_txs)
            mem_pos := assign_and_move(mem_pos, p_mass_deposits)
            mem_pos := assign_and_move(mem_pos, p_mass_migrations)
            let submission_id := keccak256(starting_mem_pos, sub(mem_pos, starting_mem_pos))
            _block := mem_pos
            mem_pos := assign_and_move(mem_pos, submission_id)
            mem_pos := assign_and_move(mem_pos, p_header)
            mem_pos := assign_and_move(mem_pos, p_body)
            mstore(0x40, mem_pos)
            if not(eq(sub(cp, start), data_len)) {
                revert(0, 0)
            }
        }
        return _block;
    }
    
    function massMigrationFromCalldataAt(uint paramIndex) internal pure returns (MassMigration memory) {
    }
    function finalizationFromCalldataAt(uint paramIndex) internal pure returns (Finalization memory) {
    }
}
