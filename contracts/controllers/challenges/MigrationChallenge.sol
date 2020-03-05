pragma solidity >= 0.6.0;

import { Layer2 } from "../../storage/Layer2.sol";
import { Challengeable } from "../Challengeable.sol";
import { SNARKsVerifier } from "../../libraries/SNARKs.sol";
import { SMT256 } from "../../../node_modules/smt-rollup/contracts/SMT.sol";
import {
    Block,
    Challenge,
    Transaction,
    Outflow,
    MassDeposit,
    MassMigration,
    ERC20Migration,
    ERC721Migration,
    Types
} from "../../libraries/Types.sol";
import { Deserializer } from "../../libraries/Deserializer.sol";

contract MigrationChallenge is Challengeable {
    using SMT256 for SMT256.OPRU;
    using SNARKsVerifier for SNARKsVerifier.VerifyingKey;
    using Types for Outflow;

    function challengeMassMigrationToMassDeposit(
        address destination,
        bytes calldata
    ) external {
        Block memory _block = Deserializer.blockFromCalldataAt(1);
        Challenge memory result = _challengeResultOfMassMigrationToMassDeposit(_block, destination);
        _execute(result);
    }

    function challengeERC20Migration(
        address destination,
        address erc20,
        bytes calldata
    ) external {
        Block memory _block = Deserializer.blockFromCalldataAt(2);
        Challenge memory result = _challengeResultOfERC20Migration(_block, destination, erc20);
        _execute(result);
    }

    function challengeERC721Migration(
        address destination,
        address erc721,
        uint tokenId,
        bytes calldata
    ) external {
        Block memory _block = Deserializer.blockFromCalldataAt(2);
        Challenge memory result = _challengeResultOfERC721Migration(
            _block,
            destination,
            erc721,
            tokenId
        );
        _execute(result);
    }

    function _challengeResultOfMassMigrationToMassDeposit(
        Block memory _block,
        address destination
    )
        internal
        view
        returns (Challenge memory)
    {
        require(destination != address(this), "It's a withdrawal");
        MassMigration memory submitted;
        for(uint i = 0; i < _block.body.massMigrations.length; i++) {
            if(destination == _block.body.massMigrations[i].destination) {
                if(submitted.destination != address(0)) {
                    return Challenge(
                        true,
                        _block.submissionId,
                        _block.header.proposer,
                        "Duplicated MassMigration destination"
                    );
                }
                submitted = _block.body.massMigrations[i];
            }
        }
        uint totalETH;
        MassDeposit memory massDeposit;
        for(uint i = 0; i < _block.body.txs.length; i++) {
            Transaction memory transaction = _block.body.txs[i];
            for(uint j = 0; j < transaction.outflow.length; j++) {
                Outflow memory outflow = transaction.outflow[j];
                if(outflow.publicData.to == destination) {
                    totalETH += outflow.publicData.eth;
                    massDeposit.fee += outflow.publicData.fee;
                    massDeposit.merged = keccak256(abi.encodePacked(massDeposit.merged, outflow.note));
                }
            }
        }
        bool validityOfMassDeposit;
        if(
            totalETH == submitted.totalETH &&
            massDeposit.merged == submitted.massDeposit.merged &&
            massDeposit.fee == submitted.massDeposit.fee
        ) {
            validityOfMassDeposit = true;
        } else {
            validityOfMassDeposit = false;
        }
        return Challenge(
            validityOfMassDeposit,
            _block.submissionId,
            _block.header.proposer,
            "Computed mass deposit is different with the submitted"
        );
    }

    function _challengeResultOfERC20Migration(
        Block memory _block,
        address destination,
        address erc20
    )
        internal
        view
        returns (Challenge memory)
    {
        require(destination != address(this), "It's a withdrawal");
        ERC20Migration memory submitted;
        for(uint i = 0; i < _block.body.massMigrations.length; i++) {
            MassMigration memory massMigration = _block.body.massMigrations[i];
            if(destination == massMigration.destination) {
                for(uint j = 0; j < massMigration.erc20.length; j++) {
                    ERC20Migration memory erc20Migration = massMigration.erc20[j];
                    if(erc20Migration.addr == erc20) {
                        if(erc20Migration.addr != address(0)) {
                            /// There exist more than 2 of erc20 migration against the address.
                            return Challenge(
                                true,
                                _block.submissionId,
                                _block.header.proposer,
                                "Duplicated ERC20 migration dests exist"
                            );
                        }
                        submitted = erc20Migration;
                    }
                }
            }
        }

        uint erc20Amount;
        for(uint i = 0; i < _block.body.txs.length; i++) {
            Transaction memory transaction = _block.body.txs[i];
            for(uint j = 0; j < transaction.outflow.length; j++) {
                Outflow memory outflow = transaction.outflow[j];
                if(
                    outflow.publicData.to == destination &&
                    outflow.publicData.token == erc20
                ) {
                    erc20Amount += outflow.publicData.amount;
                }
            }
        }
        return Challenge(
            erc20Amount == submitted.amount,
            _block.submissionId,
            _block.header.proposer,
            "Migrating amount of token is invalid"
        );
    }

    function _challengeResultOfERC721Migration(
        Block memory _block,
        address destination,
        address erc721,
        uint tokenId
    )
        internal
        view
        returns (Challenge memory)
    {
        require(destination != address(this), "It's a withdrawal");
        ERC721Migration memory submitted;
        for(uint i = 0; i < _block.body.massMigrations.length; i++) {
            MassMigration memory massMigration = _block.body.massMigrations[i];
            if(destination == massMigration.destination) {
                for(uint j = 0; j < massMigration.erc721.length; j++) {
                    ERC721Migration memory erc721Migration = massMigration.erc721[j];
                    if(erc721Migration.addr == erc721) {
                        if(erc721Migration.addr != address(0)) {
                            /// There exist more than 2 of erc721 migration against the address.
                            return Challenge(
                                true,
                                _block.submissionId,
                                _block.header.proposer,
                                "Duplicated ERC721 migration dests exist"
                            );
                        }
                        submitted = erc721Migration;
                    }
                }
            }
        }
        uint submittedNftCount = 0;
        for (uint i = 0; i < submitted.nfts.length; i++) {
            if(tokenId == submitted.nfts[i]) {
                submittedNftCount ++;
            }
        }
        if(submittedNftCount > 1) {
            return Challenge(
                true,
                _block.submissionId,
                _block.header.proposer,
                "It destroys the non-fungibility"
            );
        }

        uint computedNftCount;
        for(uint i = 0; i < _block.body.txs.length; i++) {
            Transaction memory transaction = _block.body.txs[i];
            for(uint j = 0; j < transaction.outflow.length; j++) {
                Outflow memory outflow = transaction.outflow[j];
                if(
                    outflow.publicData.to == destination &&
                    outflow.publicData.token == erc721 &&
                    outflow.publicData.nft == tokenId
                ) {
                    computedNftCount += 1;
                }
            }
        }
        return Challenge(
            submittedNftCount == computedNftCount,
            _block.submissionId,
            _block.header.proposer,
            "Invalid nft migration"
        );
    }
}
