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
     * @notice Check the validity of an inclusion refernce for a nullifier.
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