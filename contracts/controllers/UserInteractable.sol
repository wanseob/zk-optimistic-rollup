pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { Asset, AssetHandler } from "../libraries/Asset.sol";
import { Hash, Poseidon } from "../libraries/Hash.sol";
import { RollUpLib } from "../../node_modules/merkle-tree-rollup/contracts/library/RollUpLib.sol";
import { MassDeposit, Withdrawable, Types } from "../libraries/Types.sol";


contract UserInteractable is Layer2 {
    using RollUpLib for *;
    using AssetHandler for Asset;

    event Deposit(uint indexed queuedAt, uint note);

    function deposit(
        uint note,
        uint amount,
        uint salt,
        uint fee,
        uint[2] memory pubKey
    ) public payable {
        ///TODO: limit the length of a queue: 1024
        require(note != 0, "Note hash can not be zero");
        ///TODO: require(fee >= specified fee);
        /// Validate the note is same with the hash result
        uint[] memory inputs = new uint[](4);
        inputs[0] = amount;
        inputs[1] = pubKey[0];
        inputs[2] = pubKey[1];
        inputs[3] = salt;
        require(note == Poseidon.poseidon(inputs), "Invalid hash value");
        /// Receive token
        Layer2.asset.depositFrom(address(this), amount + fee);
        /// Get the mass deposit to update
        MassDeposit storage latest = chain.depositQueue[chain.depositQueue.length - 1];
        /// Commit the latest one to prevent accumulating too much (1024)
        if (!latest.committed && latest.length >= 1024) {
            latest.committed = true;
        }
        MassDeposit storage target = latest.committed ? chain.depositQueue.push() : latest;
        /// Update the mass deposit
        target.merged = keccak256(abi.encodePacked(target.merged, note));
        target.amount += amount;
        target.fee += fee;
        target.length += 1;
        /// Emit event. Coordinator should subscribe this event.
        emit Deposit(chain.depositQueue.length - 1, note);
    }

    function withdraw(
        uint amount,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings
    ) public {
        _withdraw(amount, msg.sender, proofHash, rootIndex, leafIndex, siblings);
    }

    function withdrawUsingSignature(
        uint amount,
        address to,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, proofHash));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        address signer = ecrecover(prefixedHash, v, r, s);
        require(signer == to, "Invalid signature");
        _withdraw(amount, to, proofHash, rootIndex, leafIndex, siblings);
    }

    function _withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings
    ) internal {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, proofHash));
        /// Check whether it is already withdrawn or not
        require(!chain.withdrawn[leaf], "Already withdrawn");
        /// Get the root of a withdrawable tree to use for the inclusion proof
        Withdrawable memory withdrawable = chain.withdrawables[rootIndex];
        /// Calculate the inclusion proof
        bool inclusion = Hash.keccak().merkleProof(
            uint(withdrawable.root),
            uint(leaf),
            leafIndex,
            siblings
        );
        require(inclusion, "The given withdrawal leaf does not exist");
        Layer2.asset.withdrawTo(to, amount);
    }
}
