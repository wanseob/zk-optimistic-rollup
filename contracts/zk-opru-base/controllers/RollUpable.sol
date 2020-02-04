pragma solidity >= 0.6.0;

import { OPRU, ExtendedOPRU } from "../../../node_modules/merkle-tree-rollup/contracts/library/Types.sol";
import { OPRULib } from "../../../node_modules/merkle-tree-rollup/contracts/library/OPRULib.sol";
import { SMT256 } from "../../../node_modules/smt-rollup/contracts/SMT.sol";
import { Hash } from "../../libraries/Hash.sol";
import { Layer2 } from "./../Layer2.sol";


contract RollUpable is Layer2 {
    using OPRULib for *;
    using SMT256 for SMT256.OPRU;

    enum RollUpType { UTXO, Nullifier, Withdrawal}

    event NewProofOfRollUp(RollUpType rollUpType, uint id);

    modifier requirePermission(RollUpType rollUpType, uint id) {
        require(
            Layer2.proof.permittedTo[uint8(rollUpType)][id] == msg.sender,
            "Not permitted to update this roll up"
        );
        _;
    }

    /** Roll up interaction functions */
    function newProofOfUTXORollUp(
        uint startingRoot,
        uint startingIndex,
        uint[] calldata initialSiblings
    ) external {
        ExtendedOPRU storage opru = Layer2.proof.ofUTXO.push();
        Hash.mimc().initExtendedOPRU(
            opru,
            startingRoot,
            startingIndex,
            initialSiblings
        );
        uint id = Layer2.proof.ofUTXO.length - 1;
        Layer2.proof.permittedTo[uint8(RollUpType.UTXO)][id] = msg.sender;
        emit NewProofOfRollUp(RollUpType.UTXO, id);
    }

    function newProofOfNullifierRollUp(bytes32 prevRoot) external {
        SMT256.OPRU storage opru = Layer2.proof.ofNullifier.push();
        opru.prev = prevRoot;
        opru.next = prevRoot;
        opru.mergedLeaves = bytes32(0);
        uint id = Layer2.proof.ofNullifier.length - 1;
        Layer2.proof.permittedTo[uint8(RollUpType.Nullifier)][id] = msg.sender;
        emit NewProofOfRollUp(RollUpType.Nullifier, id);
    }

    function newProofOfWithdrawalRollUp(
        uint startingRoot,
        uint startingIndex
    ) external {
        OPRU storage opru = Layer2.proof.ofWithdrawal.push();
        opru.start.root = startingRoot;
        opru.start.index = startingIndex;
        opru.result.root = startingRoot;
        opru.result.index = startingIndex;
        opru.mergedLeaves = bytes32(0);
        uint id = Layer2.proof.ofWithdrawal.length - 1;
        Layer2.proof.permittedTo[uint8(RollUpType.Withdrawal)][id] = msg.sender;
        emit NewProofOfRollUp(RollUpType.Withdrawal, id);
    }

    function updateProofOfUTXORollUp(
        uint id,
        uint[] calldata leaves
    )
        external
        requirePermission(RollUpType.Withdrawal, id)
    {
        ExtendedOPRU storage opru = Layer2.proof.ofUTXO[id];
        Hash.mimc().update(opru, leaves);
    }

    function updateProofOfNullifierRollUp(
        uint id,
        bytes32[] calldata leaves,
        bytes32[256][] calldata siblings
    )
        external
        requirePermission(RollUpType.Nullifier, id)
    {
        SMT256.OPRU storage opru = Layer2.proof.ofNullifier[id];
        opru.update(leaves, siblings);
    }

    function updateProofOfWithdrawalRollUp(
        uint id,
        uint[] calldata initialSiblings,
        uint[] calldata leaves
    )
        external
        requirePermission(RollUpType.Withdrawal, id)
    {
        OPRU storage opru = Layer2.proof.ofWithdrawal[id];
        Hash.keccak().update(opru, initialSiblings, leaves);
    }
}
