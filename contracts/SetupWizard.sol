pragma solidity >= 0.6.0;

import { ISetupWizard } from "./interfaces/ISetupWizard.sol";
import { Layer2 } from "./storage/Layer2.sol";
import { Layer2Controller } from "./Layer2Controller.sol";
import { SNARKsVerifier } from "./libraries/SNARKs.sol";
import { TxType, Types } from "./libraries/Types.sol";
import { Pairing } from "./libraries/Pairing.sol";


contract SetupWizard is Layer2Controller {
    address setupWizard;

    constructor(address _setupWizard) public {
        Layer2.asset.wallet = address(this);
        setupWizard = _setupWizard;
    }

    modifier onlySetupWizard {
        require(msg.sender == setupWizard, "Not authorized");
        _;
    }

    function registerERC20(address _erc20) public onlySetupWizard {
        Layer2.asset.erc20 = _erc20;
    }

    function registerVk(
        uint8 txType,
        uint8 numOfInputs,
        uint8 numOfOutputs,
        uint[2] memory alfa1,
        uint[2][2] memory beta2,
        uint[2][2] memory gamma2,
        uint[2][2] memory delta2,
        uint[2][] memory ic
    ) public onlySetupWizard {
        bytes32 txSig = Types.getSNARKsSignature(TxType(txType), numOfInputs, numOfOutputs);
        SNARKsVerifier.VerifyingKey storage vk = Layer2.vks[txSig];
        vk.alfa1 = Pairing.G1Point(alfa1[0], alfa1[1]);
        vk.beta2 = Pairing.G2Point(beta2[0], beta2[1]);
        vk.gamma2 = Pairing.G2Point(gamma2[0], gamma2[1]);
        vk.delta2 = Pairing.G2Point(delta2[0], delta2[1]);
        for (uint i = 0; i < ic.length; i++) {
            vk.ic.push(Pairing.G1Point(ic[i][0], ic[i][1]));
        }
    }

    function makeUserInteractable(address addr) public onlySetupWizard{
        Layer2Controller._connectUserInteractable(addr);
    }

    function makeRollUpable(address addr) public onlySetupWizard{
        Layer2Controller._connectRollUpable(addr);
    }

    function makeChallengeable(
        address challengeable1,
        address challengeable2,
        address challengeable3
    ) public onlySetupWizard {
        Layer2Controller._connectChallengeable(challengeable1, challengeable2, challengeable3);
    }

    function makeMigratable(address addr) public onlySetupWizard {
        Layer2Controller._connectMigratable(addr);
    }

    function allowMigrants(address[] memory migrants) public onlySetupWizard {
        for (uint i = 0; i < migrants.length; i++) {
            Layer2.allowedMigrants[migrants[i]] = true;
        }
    }

    function completeSetup() public onlySetupWizard {
        delete setupWizard;
    }
}
