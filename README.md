# [WIP] zk-optimistic-rollup

Private token pool with optimistic rollup for zero knowledge transfer

## Contracts

### Layer2.sol

This contract has storage variables to manage the layer2 blockchain.

```solidity
contract Layer2 is Configurated {
    /** Asset contract should be assigned by the setup wizard */
    Asset public asset;

    /** State of the layer2 blockchain is maintained by the optimistic roll up */
    Blockchain public chain;

    /** SNARKs verifying keys assigned by the setup wizard for each tx type */
    mapping(bytes32=>SNARKsVerifier.VerifyingKey) vks;

    /** Addresses allowed to migrate from. Setup wizard manages the list */
    mapping(address=>bool) allowedMigrants;

    /** Roll up proofs */
    RollUpProofs proof;
}
```

### Layer2Controller.sol

Proxy contract connected to the other controllers. This controller supports the functions of following contracts

- Coordinatable.sol
- UserInteractable.sol
- RollUpable.sol
- Coordinatable.sol
- Migratable.sol

### SetupWizard.sol

This setups the followings

- SNARKs verification keys to support multiple type of transactions.
- ERC20 to use
- Allowed migrants
- Proxied controllers

```solidity
pragma solidity >= 0.6.0;

interface ISetupWizard {
    /**
     * @dev This configures a zk SNARKs verification key to support the given transaction type
     * @param txType TxType.Transfer / TxType.Withdrawal / TxType.Migration
     * @param numOfInputs Number of inflow UTXOs
     * @param numOfOutputs Number of outflow UTXOs
     */
    function registerVk(
        uint8 txType,
        uint8 numOfInputs,
        uint8 numOfOutputs,
        uint[2] calldata alfa1,
        uint[2][2] calldata beta2,
        uint[2][2] calldata gamma2,
        uint[2][2] calldata delta2,
        uint[2][] calldata ic
    ) external;

    /**
     * @dev It configures the ERC20 to use in this pool
     */
    function registerERC20(address _erc20) external;

    /**
     * @dev It connects this proxy contract to the UserInteractable controller.
     */
    function connectUserInteractable(address addr) external;

    /**
     * @dev It connects this proxy contract to the RollUpable controller.
     */
    function connectRollUpable(address addr) external;

    /**
     * @dev It connects this proxy contract to the Challengeable controller.
     */
    function connectChallengeable(address addr) external;

    /**
     * @dev It connects this proxy contract to the Migratable controller.
     */
    function connectMigratable(address addr) external;

    /**
     * @dev Migration process:
            1. On the destination contract, execute allowMigrants() to configure the allowed migrants.
               The departure contract should be in the allowed list.
            2. On the departure contract, execute migrateTo(). See "IMigratable.sol"
     * @param migrants List of contracts' address to allow migrations.
     */
    function allowMigrants(address[] calldata migrants) external;

    /**
     * @dev If you once execute this, every configuration freezes and does not change forever.
     */
    function completeSetup() external;
}
```

## Controllers

### Coordinatable.sol

```solidity
pragma solidity >= 0.6.0;

interface ICoordinatable {
    /**
     * @notice Coordinator calls this function for the proof of stake.
     *         Coordinator should pay more than MINIMUM_STAKE. See 'Configurated.sol'
     *
     */
    function register() external payable;

    /**
     * @notice Coordinator can withdraw deposited stakes after the challenge period.
     */
    function deregister() external;

    /**
     * @dev Coordinator proposes a new block using this function. propose() will freeze
     *      the current mass deposit for the next block proposer, and will go through
     *      CHALLENGE_PERIOD.
     * @param submission Serialized newly minted block data
     */
    function propose(bytes calldata submission) external;

    /**
     * @dev Coordinator can finalize a submitted block if it isn't slashed during the
     *      challenge period. It updates the aggregated fee and withdrawal root.
     * @param submission Serialized newly minted block data
     */
    function finalize(bytes calldata submission) external;

    /**
     * @dev Coordinators can withdraw aggregated transaction fees.
     * @param amount Amount to withdraw.
     */
    function withdrawReward(uint amount) external;

    /**
     * @dev You can override this function to implement your own consensus logic.
     * @param proposerAddr Coordinator address to check the allowance of block proposing.
     */
    function isProposable(address proposerAddr) external view returns (bool);
}
```

### UserInteractable.sol

```solidity
pragma solidity >= 0.6.0;

interface IUserInteractable {
    /**
     * @notice Users can use zkopru network by submitting a new homomorphically hiden note.
     * @param note Should be same with the MiMC sponge of (amount, fee, pubKey)
     * @param amount Amount to deposit
     * @param fee Amount of fee to give to the coordinator
     * @param pubKey EdDSA public key to use in the zkopru network
     */
    function deposit(
        uint note,
        uint amount,
        uint fee,
        uint[2] calldata pubKey
    ) external payable;

    /**
     * @notice Users can withdraw a note when your withdrawal tx is finalized
     * @param amount Amount to withdraw out.
     * @param proofHash Hash value of the SNARKs proof of your withdrawal transaction.
     * @param rootIndex Withdrawer should submit inclusion proof. Submit which withdrawal root to use.
     *                  withdrawables[0]: daily snapshot of withdrawable tree
     *                  withdrawables[latest]: the latest withdrawal tree
     *                  withdrawables[1~latest-1]: finalized tree
     * @param leafIndex The index of your withdrawal note's leaf in the given tree.
     * @param siblings Inclusion proof data
     */
    function withdraw(
        uint amount,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] calldata siblings
    ) external;

    /**
     * @notice Others can execute the withdrawal instead of the recipient account using ECDSA.
     * @param amount Amount to withdraw out.
     * @param to Address of the ECDSA signer
     * @param proofHash Hash value of the SNARKs proof of your withdrawal transaction.
     * @param rootIndex Withdrawer should submit inclusion proof. Submit which withdrawal root to use.
     *                  withdrawables[0]: daily snapshot of withdrawable tree
     *                  withdrawables[latest]: the latest withdrawal tree
     *                  withdrawables[1~latest-1]: finalized tree
     * @param leafIndex The index of your withdrawal note's leaf in the given tree.
     * @param siblings Inclusion proof data
     * @param v ECDSA signature v
     * @param r ECDSA signature r
     * @param s ECDSA signature s
     */
    function withdrawUsingSignature(
        uint amount,
        address to,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] calldata siblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
```

### Migratable.sol

```solidity
pragma solidity >= 0.6.0;

interface IMigratable {
    /**
     * @dev You can do the mass migration using this function. To execute
     *      this function, the destination contract should inherits the
     *      "Migratable" contract and have registered this current contract's
     *      address as an allowed migrant.
     * @param migrationId Index of a MassMigration to execute.
     * @param to Address of the destination contract.
     */
    function migrateTo(uint migrationId, address to) external;
}
```

### RollUpable.sol

```solidity
pragma solidity >= 0.6.0;

interface IRollUpable {
    /**
     * @dev Challenger starts to generate a proof for the UTXO tree transition
     */
    function newProofOfUTXORollUp(uint startingRoot, uint startingIndex, uint[] calldata initialSiblings) external;

    /**
     * @dev Challenger starts to generate a proof for the nullifier tree transition
     */
    function newProofOfNullifierRollUp(bytes32 prevRoot) external;

    /**
     * @dev Challenger starts to generate a proof for the withdrawal tree transition
     */
    function newProofOfWithdrawalRollUp(uint startingRoot, uint startingIndex) external;

    /**
     * @dev Challenger appends items to the utxo tree and record the intermediate result on the storage.
     *      This MiMC roll up costs around 1.4 million to append an item.
     */
    function updateProofOfUTXORollUp(uint id, uint[] calldata leaves) external;

    /**
     * @dev Challenger appends items to the nullifier tree and record the intermediate result on the storage.
     */
    function updateProofOfNullifierRollUp(uint id, bytes32[] calldata leaves, bytes32[256][] calldata siblings) external;

    /**
     * @dev Challenger appends items to the withdrawal tree and record the intermediate result on the storage
     */
    function updateProofOfWithdrawalRollUp(uint id, uint[] calldata initialSiblings, uint[] calldata leaves) external;
}
```

### Challengeable.sol

```solidity
pragma solidity >= 0.6.0;

interface IChallengeable {
    /**
     * @dev Challenge when the submitted block's utxo tree transition is invalid.
     * @param proofId Id of your utxo roll up proof. See 'RollUpable.sol'.
     * @param deposits Submit all deposit leaves to be merged.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeUTXORollUp(uint proofId, uint[] calldata deposits, bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted block's nullifier tree transition is invalid.
     * @param proofId Id of your nullifier roll up proof. See 'RollUpable.sol'.
     * @param siblings Siblings for every single roll up
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeNullifierRollUp(uint proofId, bytes32[256][] calldata siblings, bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted header's deposit root is invalid.
     *      The Deposit root in the header should be the merkle root of the total
     *      deposits to newly append to the UTXO tree.
     * @param deposits All deposit leaves in the included MassDeposits.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeDepositRoot(uint[] calldata deposits, bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted header's transfer root is invalid.
     *      The transfer root in the header should be the merkle root of the transfer
     *      tx hash values.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeTransferRoot(bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted header's withdrawal root is invalid.
     *      The withdrawal root in the header should be the merkle root of the withdraw
     *      tx hash values.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeWithdrawalRoot(bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted header's migration root is invalid.
     *      The migration root in the header should be the merkle root of the migration
     *      tx hash values.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeMigrationRoot(bytes calldata submission) external;

    /**
     * @dev Challenge when the submitted header's total fee is not same with
     *      the sum of the fees in every transactions in the block.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeTotalFee(bytes calldata submission) external;

    /**
     * @dev Challenge when any of the used nullifier's inclusion reference is invalid.
     * @param txType Type of the transaction.
     * @param txIndex Index of the transaction in the tx list of the block body.
     * @param refIndex Index of the invalid inclusion reference's in the tx detail data.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeInclusion(uint8 txType, uint txIndex, uint refIndex, bytes calldata submission) external;

    /**
     * @dev Challenge when any submitted transaction has an invalid SNARKs proof
     * @param txType Type of the transaction.
     * @param txIndex Index of the transaction in the tx list of the block body.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeTransaction(uint8 txType, uint txIndex, bytes calldata submission) external;

    /**
     * @dev Challenge when the block is trying to use an already used nullifier.
     * @param txType Type of the transaction.
     * @param txIndex Index of the transaction in the tx list of the block body.
     * @param nullifierIndex Index of the nullifier in the tx detail data.
     * @param sibling The sibling data of the nullifier.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeUsedNullifier(uint8 txType, uint txIndex, uint nullifierIndex, bytes32[256] calldata sibling, bytes calldata submission) external;

    /**
     * @dev Challenge when a nullifier used twice in a same block.
     * @param nullifier Double included nullifier.
     * @param submission The proposal data which is exactly same with the submitted.
     */
    function challengeDuplicatedNullifier(bytes32 nullifier, bytes calldata submission) external;

    /**
     * @notice It checks the validity of an inclusion refernce for a nullifier.
     * @dev Each nullifier should be paired with an inclusion reference which is a root of
     *      utxo tree. For the inclusion reference, You can use finalized roots or recent
     *      blocks' utxo roots. When you use recent blocks' utxo roots, recent REF_DEPTH
     *      of utxo roots are available. It costs maximum 1800*REF_DEPTH gas to validate
     *      an inclusion reference during the TX challenge process.
     * @param l2BlockHash Layer2 block's hash value where to start searching for.
     * @param ref Utxo root which includes the nullifier's origin utxo.
     */
    function isValidRef(bytes32 l2BlockHash, uint256 ref) external view returns (bool);
}
```

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

- type: (1 byte) type of the transaction 0: transfer 1: withdraw 2: migration
- n_i: (1 byte) number of inputs
- n_o: (1 byte) number of outputs
- fee: (32 bytes)
- inclusion_refs: (n_i \* 32 bytes) inclusion reference roots
- nullifiers: (n_i \* 32 bytes) nullifiers to prevent double spending which will be rolled up to the nullifier tree
- outputs: (n_o \* 32 bytes) output leaves will be rolled up to the output_tree when it is a transfer tx. If it is a withdraw tx, then they will be rolled up to the withdrawal_tree
- proof: (256 bytes) zk SNARKs proof
  total size = 3 + 32 + n*i * 64 + n*o * 32 + 256 = 451 bytes ~

# Credits to

- Lunar Davenport
- Kobi Gurk
