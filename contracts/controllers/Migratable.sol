pragma solidity >= 0.6.0;

import { Layer2 } from "../storage/Layer2.sol";
import { Asset, AssetHandler } from "../libraries/Asset.sol";
import { MassDeposit, MassMigration, Types } from "../libraries/Types.sol";


contract Migratable is Layer2 {
    using Types for *;
    using AssetHandler for Asset;

    function migrate(uint amount, uint fee, uint length, bytes32 mergedLeaves) external virtual {
        require(Layer2.allowedMigrants[msg.sender], "Not an allowed departure");
        MassDeposit storage latest = Layer2.chain.depositQueue[
            Layer2.chain.depositQueue.length - 1
        ];
        latest.committed = true;
        Layer2.chain.depositQueue.push(
            MassDeposit(
                mergedLeaves,
                amount,
                fee,
                length,
                true
            )
        );
    }

    function migrateTo(
        uint migrationId,
        address to
    ) public {
        MassMigration storage migration = Layer2.chain.migrations[migrationId];
        require(to == migration.destination, "Not authorized");
        try Migratable(to).migrate(
            migration.amount,
            migration.migrationFee,
            migration.length,
            migration.mergedLeaves
        ) {
            /// Transfer assets
            Layer2.asset.withdrawTo(
                migration.destination,
                (migration.amount+migration.migrationFee)
            );
            /// Delete mass migration
            delete Layer2.chain.migrations[migrationId];
        } catch {
           revert("Migration executor has a problem");
        }
    }
}
