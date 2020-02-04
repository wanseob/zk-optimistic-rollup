pragma solidity >= 0.6.0;

interface IRollUpable {
    function newProofOfUTXORollUp(uint startingRoot, uint startingIndex, uint[] calldata initialSiblings) external;

    function newProofOfNullifierRollUp(bytes32 prevRoot) external;

    function newProofOfWithdrawalRollUp(uint startingRoot, uint startingIndex) external;

    function updateProofOfUTXORollUp(uint id, uint[] calldata leaves) external;

    function updateProofOfNullifierRollUp(uint id, bytes32[] calldata leaves, bytes32[256][] calldata siblings) external;

    function updateProofOfWithdrawalRollUp(uint id, uint[] calldata initialSiblings, uint[] calldata leaves) external;
}