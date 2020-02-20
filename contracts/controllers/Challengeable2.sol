pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { Challengeable } from "./Challengeable.sol";
import {
    Block,
    Challenge,
    MassDeposit,
    Types
} from "../libraries/Types.sol";

contract Challengeable2 is Challengeable {
    using Types for *;

    function challengeDepositRoot(
        uint[] calldata deposits,
        bytes calldata
    ) external {
        Block memory submission = Types.blockFromCalldataAt(1);
        Challenge memory result = _challengeResultOfDepositRoot(submission, deposits);
        _execute(result);
    }

    function challengeWithdrawalRoot(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfWithdrawalRoot(submission);
        _execute(result);
    }

    function challengeMigrationRoot(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfMigrationRoot(submission);
        _execute(result);
    }
    function challengeTotalFee(bytes calldata) external {
        Block memory submission = Types.blockFromCalldataAt(0);
        Challenge memory result = _challengeResultOfTotalFee(submission);
        _execute(result);
    }

    function _challengeResultOfDepositRoot(
        Block memory submission,
        uint[] memory deposits
    )
        internal
        view
        returns (Challenge memory)
    {
        uint index = 0;
        bytes32 merged;
        for (uint i = 0; i < submission.body.depositIds.length; i++) {
            merged = bytes32(0);
            MassDeposit storage depositsToAdd = Layer2.chain.depositQueue[submission.body.depositIds[i]];
            if (!depositsToAdd.committed) {
                return Challenge(
                    true,
                    submission.id,
                    submission.header.proposer,
                    "This deposit queue is not committed"
                );
            }
            for (uint j = 0; j < depositsToAdd.length; j++) {
                merged = keccak256(abi.encodePacked(merged, deposits[index]));
                index++;
            }
            require(merged == depositsToAdd.merged, "Invalid set of deposits");
        }
        require(index == deposits.length, "Submitted extra deposits");
        return Challenge(
            submission.header.depositRoot != deposits.root(),
            submission.id,
            submission.header.proposer,
            "Deposit root validation"
        );
    }

    function _challengeResultOfL2TxRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.l2TxRoot != submission.body.l2Txs.root(),
            submission.id,
            submission.header.proposer,
            "Transfer root validation"
        );
    }

    function _challengeResultOfWithdrawalRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.withdrawalRoot != submission.body.withdrawals.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfMigrationRoot(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        return Challenge(
            submission.header.migrationRoot != submission.body.migrations.root(),
            submission.id,
            submission.header.proposer,
            "Withdrawal root validation"
        );
    }

    function _challengeResultOfTotalFee(
        Block memory submission
    )
        internal
        pure
        returns (Challenge memory)
    {
        uint totalFee = 0;
        for (uint i = 0; i < submission.body.l2Txs.length; i ++) {
            totalFee += submission.body.l2Txs[i].fee;
        }
        for (uint i = 0; i < submission.body.withdrawals.length; i ++) {
            totalFee += submission.body.withdrawals[i].fee;
        }
        for (uint i = 0; i < submission.body.migrations.length; i ++) {
            totalFee += submission.body.migrations[i].fee;
        }
        return Challenge(
            totalFee != submission.header.fee,
            submission.id,
            submission.header.proposer,
            "Total fee validation"
        );
    }
}
