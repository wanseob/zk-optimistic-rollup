pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { IERC721 } from "../utils/IERC721.sol";
import { Asset, AssetHandler } from "../libraries/Asset.sol";
import { Hash, Poseidon, MiMC } from "../libraries/Hash.sol";
import { RollUpLib } from "../../node_modules/merkle-tree-rollup/contracts/library/RollUpLib.sol";
import { MassDeposit, Withdrawable, Types } from "../libraries/Types.sol";

/// TODO: Add uint size checker for SNARKs field

contract UserInteractable is Layer2 {
    uint public constant SNARKS_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
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
        uint256 nft = 0;
        _deposit(note, amount, salt, fee, nft, pubKey);
    }

    function deposit(
        uint note,
        uint amount,
        address erc721,
        uint tokenId,
        uint salt,
        uint fee,
        uint[2] memory pubKey
    ) public payable {
        try IERC721(erc721).transferFrom(msg.sender, address(this), tokenId) {
            uint256 nft = nftHash(erc721, tokenId);
            _deposit(note, amount, salt, fee, nft, pubKey);
        } catch {
            revert("Transfer NFT failed");
        }
    }

    function withdraw(
        uint amount,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings
    ) public {
        uint256 nft = 0;
        _withdraw(amount, msg.sender, proofHash, nft, rootIndex, leafIndex, siblings);
    }

    function withdraw(
        uint amount,
        address erc721,
        uint tokenId,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings
    ) public {
        try IERC721(erc721).transferFrom(address(this), msg.sender, tokenId) {
            uint256 nft = nftHash(erc721, tokenId);
            _withdraw(amount, msg.sender, proofHash, nft, rootIndex, leafIndex, siblings);
        } catch {
            revert("Failed to withdraw nft");
        }
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
        uint256 nft = 0;
        require(
            _verifyWithdrawalSignature(amount, to, nft, proofHash, v, r, s),
            "Invalid signature"
        );
        _withdraw(amount, to, proofHash, nft, rootIndex, leafIndex, siblings);
    }

    function withdrawUsingSignature(
        uint amount,
        address to,
        address erc721,
        uint tokenId,
        bytes32 proofHash,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        uint256 nft = nftHash(erc721, tokenId);
        require(
            _verifyWithdrawalSignature(amount, to, nft, proofHash, v, r, s),
            "Invalid signature"
        );
        try IERC721(erc721).transferFrom(address(this), to, tokenId) {
            _withdraw(amount, to, proofHash, nft, rootIndex, leafIndex, siblings);
        } catch {
            revert("Failed to withdraw nft");
        }
    }

    function snarksField(uint value) public pure returns (uint) {
        require(value <= SNARKS_FIELD, "It requires the value should be in the snarks field");
        return value;
    }

    function nftHash(address erc721, uint256 tokenId) public pure returns (uint256) {
        /// MiMC Sponge hashing to generate SNARKs field compatible hash value
        /// Note that this is just to generate the hashed value, and we do not
        /// do any MiMC hash in the SNARKs circuits.
        uint256 R = 0;
        uint256 C = 0;

        R = addmod(R, uint(erc721), SNARKS_FIELD);
        (R, C) = MiMC.MiMCSponge(R, C, 0);

        R = addmod(R, uint(tokenId), SNARKS_FIELD);
        (R, C) = MiMC.MiMCSponge(R, C, 0);
        return snarksField(R);
    }

    function _verifyWithdrawalSignature(
        uint256 amount,
        address to,
        uint256 nft,
        bytes32 proofHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, nft, proofHash));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", leaf));
        address signer = ecrecover(prefixedHash, v, r, s);
        return signer == to;
    }

    function _deposit(
        uint note,
        uint amount,
        uint salt,
        uint fee,
        uint nft,
        uint[2] memory pubKey
    ) internal {
        ///TODO: limit the length of a queue: 1024
        require(note != 0, "Note hash can not be zero");
        ///TODO: require(fee >= specified fee);
        /// Validate the note is same with the hash result
        uint[] memory inputs = new uint[](5);
        inputs[0] = amount;
        inputs[1] = pubKey[0];
        inputs[2] = pubKey[1];
        inputs[3] = uint(nft);
        inputs[4] = salt;
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

    function _withdraw(
        uint amount,
        address to,
        bytes32 proofHash,
        uint256 nft,
        uint rootIndex,
        uint leafIndex,
        uint[] memory siblings
    ) internal {
        bytes32 leaf = keccak256(abi.encodePacked(amount, to, nft, proofHash));
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
