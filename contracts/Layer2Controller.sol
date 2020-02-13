pragma solidity >= 0.6.0;

import { Coordinatable } from "./controllers/Coordinatable.sol";
import { SNARKsVerifier } from "./libraries/SNARKs.sol";
import { TxType, Types } from "./libraries/Types.sol";
import { Pairing } from "./libraries/Pairing.sol";
import { IUserInteractable } from "./interfaces/IUserInteractable.sol";
import { IRollUpable } from "./interfaces/IRollUpable.sol";
import { IMigratable } from "./interfaces/IMigratable.sol";
import { IChallengeable } from "./interfaces/IChallengeable.sol";


contract Layer2Controller is Coordinatable {
    /** Addresses where to execute the given function call */
    mapping(bytes4=>address) public proxied;

    /**
     * @notice This proxies supports the following interfaces
     *          - ICoordinatable.sol
     *          - IUserInteractable.sol
     *          - IRollUpable.sol
     *          - IChallengeable.sol
     *          - IMigratable.sol
     */
    fallback () external payable {
        bytes4 sig = abi.decode(msg.data[:4], (bytes4));
        address addr = proxied[sig];
        assembly {
            let freememstart := mload(0x40)
            calldatacopy(freememstart, 0, calldatasize())
            let success := delegatecall(not(0), addr, freememstart, calldatasize(), freememstart, 32)
            switch success
            case 0 { revert(freememstart, 32) }
            default { return(freememstart, 32) }
        }
    }

    /**
     * @dev See Coordinatable.sol's register() function
    */
    receive() external payable {
        Coordinatable.register();
    }

    function _connectUserInteractable(address addr) internal {
        _connect(addr, IUserInteractable(0).deposit.selector);
        _connect(addr, IUserInteractable(0).withdraw.selector);
        _connect(addr, IUserInteractable(0).withdrawUsingSignature.selector);
    }

    function _connectRollUpable(address addr) internal {
        _connect(addr, IRollUpable(0).newProofOfUTXORollUp.selector);
        _connect(addr, IRollUpable(0).newProofOfNullifierRollUp.selector);
        _connect(addr, IRollUpable(0).newProofOfWithdrawalRollUp.selector);
        _connect(addr, IRollUpable(0).updateProofOfUTXORollUp.selector);
        _connect(addr, IRollUpable(0).updateProofOfNullifierRollUp.selector);
        _connect(addr, IRollUpable(0).updateProofOfWithdrawalRollUp.selector);
    }

    function _connectChallengeable(
        address challengeable1,
        address challengeable2,
        address challengeable3
    ) internal virtual {
        _connect(challengeable1, IChallengeable(0).challengeUTXORollUp.selector);
        _connect(challengeable1, IChallengeable(0).challengeNullifierRollUp.selector);
        _connect(challengeable1, IChallengeable(0).challengeWithdrawalRollUp.selector);
        _connect(challengeable2, IChallengeable(0).challengeDepositRoot.selector);
        _connect(challengeable2, IChallengeable(0).challengeTransferRoot.selector);
        _connect(challengeable2, IChallengeable(0).challengeWithdrawalRoot.selector);
        _connect(challengeable2, IChallengeable(0).challengeMigrationRoot.selector);
        _connect(challengeable2, IChallengeable(0).challengeTotalFee.selector);
        _connect(challengeable3, IChallengeable(0).challengeInclusion.selector);
        _connect(challengeable3, IChallengeable(0).challengeTransaction.selector);
        _connect(challengeable3, IChallengeable(0).challengeUsedNullifier.selector);
        _connect(challengeable3, IChallengeable(0).challengeDuplicatedNullifier.selector);
        _connect(challengeable3, IChallengeable(0).isValidRef.selector);
    }

    function _connectMigratable(address addr) internal virtual {
        _connect(addr, IMigratable(0).migrateTo.selector);
    }

    function _connect(address to, bytes4 sig) internal {
        proxied[sig] = to;
    }
}
