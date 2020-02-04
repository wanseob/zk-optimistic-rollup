pragma solidity >= 0.6.0;

interface ICoordinatable {
    function register() external payable;

    function deregister() external;

    function propose(bytes calldata) external;

    function finalize(bytes calldata) external;

    function withdrawReward(uint amount) external;

    function isProposable(address proposerAddr) external view returns (bool);
}