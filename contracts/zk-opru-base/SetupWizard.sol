pragma solidity >= 0.6.0;

import { ZkOptimisticRollUpStore } from "./ZkOptimisticRollUpStore.sol";
import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { Layer2 } from "../libraries/Layer2.sol";
import { Pairing } from "../libraries/Pairing.sol";


contract SetupWizard is ZkOptimisticRollUpStore {
    address setupWizard;
    constructor(
        address _erc20,
        address _setupWizard
    ) public {
        ZkOptimisticRollUpStore.l1Asset = _erc20;
        setupWizard = _setupWizard;
    }

    modifier onlySetupWizard {
        require(msg.sender == setupWizard, "Not authorized");
        _;
    }

    function registerVk(
        Layer2.TxType txType,
        uint8 numOfInputs,
        uint8 numOfOutputs,
        uint[2] memory alfa1,
        uint[2][2] memory beta2,
        uint[2][2] memory gamma2,
        uint[2][2] memory delta2,
        uint[2][] memory ic
    ) public onlySetupWizard {
        bytes32 txSig = Layer2.getSNARKsSignature(txType, numOfInputs, numOfOutputs);
        SNARKsVerifier.VerifyingKey storage vk = ZkOptimisticRollUpStore.vks[txSig];
        vk.alfa1 = Pairing.G1Point(alfa1[0], alfa1[1]);
        vk.beta2 = Pairing.G2Point(beta2[0], beta2[1]);
        vk.gamma2 = Pairing.G2Point(gamma2[0], gamma2[1]);
        vk.delta2 = Pairing.G2Point(delta2[0], delta2[1]);
        for (uint i = 0; i < ic.length; i++) {
            vk.ic.push(Pairing.G1Point(ic[i][0], ic[i][1]));
        }
    }

    function completeSetup() public onlySetupWizard {
        delete setupWizard;
    }
}
