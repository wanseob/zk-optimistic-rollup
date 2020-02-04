pragma solidity >= 0.6.0;

interface ISetupWizard {
    function registerERC20(address _erc20) external;

    function registerUIContract(address addr, bytes4[] calldata sigs) external;

    function registerRollUpContract(address addr, bytes4[] calldata sigs) external;

    function registerChallengeContract(address addr, bytes4[] calldata sigs) external;

    function registerMigrateContract(address addr, bytes4[] calldata sigs) external;

    function registerVk(
        uint8 txType,
        uint8 numOfInputs,
        uint8 numOfOutputs,
        uint[2] calldata alfa1,
        uint[2][2] calldata beta2,
        uint[2][2] calldata gamma2,
        uint[2][2] calldata delta2,
        uint[2][] calldata ic
    ) external;

    function allowMigrants(address[] calldata migrants) external;

    function completeSetup() external;
}