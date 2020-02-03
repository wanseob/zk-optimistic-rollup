pragma solidity >= 0.6.0;

import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { Layer1 } from "../libraries/Layer1.sol";
import { Layer2 } from "../libraries/Layer2.sol";
import { Hash } from "../libraries/Hash.sol";
import { RollUpLib } from "../../node_modules/merkle-tree-rollup/contracts/library/RollUpLib.sol";


contract UserInteractable is ZkOptimisticRollUpStore {
    using RollUpLib for *;
    using Layer1 for address;

    event Deposit(uint indexed queuedIn, uint note);
    function deposit(uint note, uint amount, uint[2] memory pubKey, uint fee) public payable {
        ///TODO: limit the length of a queue: 1024
        require(note != 0, "Note hash can not be zero");
        ///TODO: require(fee >= specified fee);
        /// Validate the note is same with the hash result
        uint[] memory inputs = new uint[](4);
        inputs[0] = amount;
        inputs[1] = pubKey[0];
        inputs[2] = pubKey[1];
        require(note == Hash.mimcHash(inputs), "Invalid hash value");
        /// Receive token
        l1Asset.toLayer2(address(this), amount + fee);
        /// Get the mass deposit to update
        Layer2.MassDeposit storage latest = l2Chain.depositQueue[l2Chain.depositQueue.length - 1];
        /// Commit the latest one to prevent accumulating too much (1024)
        if (!latest.committed && latest.length >= 1024) {
            latest.committed = true;
        }
        Layer2.MassDeposit storage target = latest.committed ? l2Chain.depositQueue.push() : latest;
        /// Update the mass deposit
        target.merged = keccak256(abi.encodePacked(target.merged, note));
        target.amount += amount;
        target.fee += fee;
        target.length += 1;
        /// Emit event. Coordinator should subscribe this event.
        emit Deposit(l2Chain.depositQueue.length - 1, note);
    }

    function withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint refId,
        uint index,
        uint[] memory siblings
    ) public {
        require(to == msg.sender, "Not authorized");
        _withdraw(amount, to, proofHash, refId, index, siblings);
    }

    function withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint refId,
        uint index,
        uint[] memory siblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, proofHash));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        require(to == ecrecover(prefixedHash, v, r, s), "Invalid signature");
        _withdraw(amount, to, proofHash, refId, index, siblings);
    }

    function _withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint refId,
        uint index,
        uint[] memory siblings
    ) internal {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, proofHash));
        /// Check withdrawable
        require(!l2Chain.withdrawn[leaf], "Already withdrawn");
        /// Get inclusion ref
        Layer2.Withdrawable memory withdrawable = l2Chain.withdrawables[refId];
        /// Inclusion proof
        bool inclusion = Hash.keccak().merkleProof(
            uint(withdrawable.root),
            uint(leaf),
            index,
            siblings
        );
        require(inclusion, "The given withdrawal leaf does not exist");
        l1Asset.withdrawFromLayer2(to, amount);
    }
}
