pragma solidity >= 0.6.0;

interface IChallengeable {
    function challengeUTXORollUp(uint proofId, uint[] calldata deposits, bytes calldata) external;

    function challengeNullifierRollUp(uint proofId, bytes32[256][] calldata siblings, bytes calldata) external;

    function challengeDepositRoot(uint[] calldata deposits,bytes calldata) external;

    function challengeTransferRoot(bytes calldata) external;

    function challengeWithdrawalRoot(bytes calldata) external;

    function challengeMigrationRoot(bytes calldata) external;

    function challengeTotalFee(bytes calldata) external;

    function challengeInclusion(uint8 txType, uint txIndex, uint refIndex, bytes calldata) external;

    function challengeTransaction(uint8 txType, uint txIndex, bytes calldata) external;

    function challengeUsedNullifier(bytes32 nullifier, bytes32[256] calldata sibling, bytes calldata) external;

    function challengeDuplicatedNullifier(bytes32 nullifier, bytes calldata) external;

    function isValidRef(bytes32 l2BlockHash, uint256 ref) external view returns (bool);
}