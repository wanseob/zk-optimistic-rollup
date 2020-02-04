pragma solidity >= 0.6.0;

import "../libraries/Types.sol";
import { Pairing } from "../libraries/Pairing.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { Asset } from "../libraries/Asset.sol";
import { Configurated } from "./Configurated.sol";


contract Layer2 is Configurated {
    /** Asset contract should be assigned by the setup wizard */
    Asset public asset;

    /** State of the layer2 blockchain is maintained by the optimistic roll up */
    Blockchain public chain;

    /** SNARKs verifying keys assigned by the setup wizard for each tx type */
    mapping(bytes32=>SNARKsVerifier.VerifyingKey) vks;

    /** Addresses allowed to migrate from. Setup wizard manages the list */
    mapping(address=>bool) allowedMigrants;
}
