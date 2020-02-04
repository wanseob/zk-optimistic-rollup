pragma solidity >= 0.6.0;

import { SNARKsVerifier } from "../libraries/SNARKs.sol";
import { TxType, Types } from "../libraries/Types.sol";
import { Pairing } from "../libraries/Pairing.sol";
import { Coordinatable } from "./controllers/Coordinatable.sol";

contract Layer2Controller is Coordinatable {
    address internal ui;
    address internal rollUp;
    address internal challenge;
    address internal migrate;

    mapping(bytes4=>address) public proxied;

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

    receive() external payable {
        Coordinatable.register();
    }
}
