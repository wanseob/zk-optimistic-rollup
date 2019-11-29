# zk-optimistic-rollup

Private token pool with optimistic rollup for zero knowledge transfer

# Credits to

- Lunar Davenport
- Kobi Gurk

## Project structure

1. zk-SNARKs circuits
2. Client
   - Manages UTXOs
   - Manages nullifiers
   - Provide API
     - Get UTXOs with prefix
     - Get Merkle Proofs
   - UTXO secret keys management
   - Manage spendable coins
   - Tx build function
   - Listen smart contract
3. Coordinator
   - Manage TX Pool
   - Interact with smart contract
