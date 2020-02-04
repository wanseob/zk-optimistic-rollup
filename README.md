# [WIP] zk-optimistic-rollup

Private token pool with optimistic rollup for zero knowledge transfer

## Fro development

### Contracts

#### Layer2.sol

This contract has storage variables to manage the layer2 blockchain.

#### Configurated.sol

You can setup detail configurations here.

#### SetupWizard.sol

This contract has initial setup functions.

#### Coordinatable.sol

This contract has functions to interact with the coordinator.

#### UserInteractable.sol

This contract has functions to interact with the user.

#### Migratable.sol

You can execute mass migration between layer2 networks which inherit this contract.

#### RollUp.sol

This contract stores roll up proofs to verify the state transition of the layer2.

#### Challengeable.sol

Challenger can dryrun or execute challenges using this contract.

####

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

## ZkTransfer

- n_i: (1 byte) number of inputs
- n_o: (1 byte) number of outputs
- type: (1 byte) type of the transaction 0: transfer 1: withdraw
- fee: (32 bytes)
- inclusion_refs: (n_i \* 32 bytes) inclusion reference roots
- nullifiers: (n_i \* 32 bytes) nullifiers to prevent double spending which will be rolled up to the nullifier tree
- outputs: (n_o \* 32 bytes) output leaves will be rolled up to the output_tree when it is a transfer tx. If it is a withdraw tx, then they will be rolled up to the withdrawal_tree
- proof: (256 bytes) zk SNARKs proof
  total size = 3 + 32 + n*i * 64 + n*o * 32 + 256 = 451 bytes ~

# Credits to

- Lunar Davenport
- Kobi Gurk
