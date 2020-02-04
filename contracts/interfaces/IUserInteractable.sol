pragma solidity >= 0.6.0;

interface IUserInteractable {
    function deposit(
        uint note,
        uint amount,
        uint fee,
        uint[2] calldata pubKey
    ) external payable;

    function withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint refId,
        uint index,
        uint[] calldata siblings
    ) external;

    function withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint refId,
        uint index,
        uint[] calldata siblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}