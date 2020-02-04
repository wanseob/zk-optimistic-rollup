pragma solidity >= 0.6.0;

interface IMigratable {
    function migrateTo(uint migrationId, address to) external;
}