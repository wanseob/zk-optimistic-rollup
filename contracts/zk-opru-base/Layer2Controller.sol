pragma solidity >= 0.6.0;

import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { TxType, Types } from "../libraries/Types.sol";
import { Pairing } from "../libraries/Pairing.sol";
import { Coordinatable } from "./controllers/Coordinatable.sol";
import { IUserInteractable } from "../interfaces/IUserInteractable.sol";
import { IRollUpable } from "../interfaces/IRollUpable.sol";
import { IMigratable } from "../interfaces/IMigratable.sol";
import { IChallengeable } from "../interfaces/IChallengeable.sol";

library ProxyConnector {
    function connect(bytes4 sig, mapping(bytes4=>address) storage proxied, address to) internal {
        proxied[sig] = to;
    }
}

contract Layer2Controller is Coordinatable {
    using ProxyConnector for bytes4;

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
        IUserInteractable(0).deposit.selector.connect(proxied, addr);
        IUserInteractable(0).withdraw.selector.connect(proxied, addr);
        IUserInteractable(0).withdrawUsingSignature.selector.connect(proxied, addr);
    }

    function _connectRollUpable(address addr) internal {
        IRollUpable(0).newProofOfUTXORollUp.selector.connect(proxied, addr);
        IRollUpable(0).newProofOfNullifierRollUp.selector.connect(proxied, addr);
        IRollUpable(0).newProofOfWithdrawalRollUp.selector.connect(proxied, addr);
        IRollUpable(0).updateProofOfUTXORollUp.selector.connect(proxied, addr);
        IRollUpable(0).updateProofOfNullifierRollUp.selector.connect(proxied, addr);
        IRollUpable(0).updateProofOfWithdrawalRollUp.selector.connect(proxied, addr);
    }

    function _connectChallengeable(address addr) internal {
        IChallengeable(0).challengeUTXORollUp.selector.connect(proxied, addr);
        IChallengeable(0).challengeNullifierRollUp.selector.connect(proxied, addr);
        IChallengeable(0).challengeDepositRoot.selector.connect(proxied, addr);
        IChallengeable(0).challengeTransferRoot.selector.connect(proxied, addr);
        IChallengeable(0).challengeWithdrawalRoot.selector.connect(proxied, addr);
        IChallengeable(0).challengeMigrationRoot.selector.connect(proxied, addr);
        IChallengeable(0).challengeTotalFee.selector.connect(proxied, addr);
        IChallengeable(0).challengeInclusion.selector.connect(proxied, addr);
        IChallengeable(0).challengeTransaction.selector.connect(proxied, addr);
        IChallengeable(0).challengeUsedNullifier.selector.connect(proxied, addr);
        IChallengeable(0).challengeDuplicatedNullifier.selector.connect(proxied, addr);
        IChallengeable(0).isValidRef.selector.connect(proxied, addr);
    }

    function _connectMigratable(address addr) internal {
        IMigratable(0).migrateTo.selector.connect(proxied, addr);
    }
}
