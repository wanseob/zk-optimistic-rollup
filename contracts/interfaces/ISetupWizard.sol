pragma solidity >= 0.6.0;

interface ISetupWizard {
    /**
     * @dev Register zk SNARKs verification key to support each transaction type
     * @param txType TxType.Transfer / TxType.Withdrawal / TxType.Migration
     * @param numOfInputs Number of inflow UTXOs
     * @param numOfOutputs Number of outflow UTXOs
     */
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

    /**
     * @dev Register ERC20 to use in this pool
     */
    function registerERC20(address _erc20) external;

    /**
     * @dev Deploy UserInteractable contract and conect this contract to the deployed.
     */
    function connectUserInteractable(address addr) external;

    /**
     * @dev Deploy RollUpable contract and conect this contract to the deployed.
     */
    function connectRollUpable(address addr) external;

    /**
     * @dev Deploy Challengeable contract and conect this contract to the deployed.
     */
    function connectChallengeable(address addr) external;

    /**
     * @dev Deploy Migratable contract and conect this contract to the deployed.
     */
    function connectMigratable(address addr) external;

    /**
     * @dev Migration process:
            1. On the destination contract, execute allowMigrants() to configure the allowed migrants.
               The departure contract should be in the allowed list.
            2. On the departure contract, execute migrateTo(). See "IMigratable.sol"
     * @param migrants List of contracts' address to allow migrations.
     */
    function allowMigrants(address[] calldata migrants) external;

    /**
     * @dev If you once execute this, every configuration freezes and does not change forever.
     */
    function completeSetup() external;
}