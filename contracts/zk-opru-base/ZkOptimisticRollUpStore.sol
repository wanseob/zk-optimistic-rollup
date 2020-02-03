pragma solidity >= 0.6.0;

import { Layer2 } from "../libraries/Layer2.sol";
import { Pairing } from "../libraries/Pairing.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { Configurated } from "./Configurated.sol";


contract ZkOptimisticRollUpStore is Configurated {
    /** Layer1 contract should be assigned by the setup wizard */
    address public l1Asset;

    /** State of the layer2 blockchain is maintained by the optimistic roll up */
    Layer2.Blockchain public l2Chain;

    /** SNARKs verifying keys assigned by the setup wizard for each tx type */
    // mapping(uint8=>mapping(uint8=>SNARKsVerifier.VerifyingKey)) vks;
    mapping(bytes32=>SNARKsVerifier.VerifyingKey) vks;
}
