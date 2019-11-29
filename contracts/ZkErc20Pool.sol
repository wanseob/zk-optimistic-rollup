pragma solidity >=0.4.21 <0.6.0;
import { OptimisticSNARKsRollUp } from  "./OptimisticSNARKsRollUp.sol";

/**
 */
contract ZkErc20Pool is OptimisticSNARKsRollUp {
    address public controller;
    address public coordinator;

    modifier onlyController {
        require(msg.sender == controller, "Only the controller can run this method");
        _;
    }

    modifier onlyCoordinator {
        require(msg.sender == coordinator, "Only the coordinator can run this method");
        _;
    }

    constructor() public {
        controller = msg.sender;
    }

    function setController(address _controller) public onlyController {
        controller = _controller;
    }

    function setCoordinator(address _coordinator) public onlyController {
        coordinator = _coordinator;
    }

    function deposit(address erc20, uint amount) public payable;
    function withdraw() public;

    function outputRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function nullifierRollUp(bytes32 prevRoot, bytes32[] memory leaves, bytes32[256][] memory siblings) public pure returns (bytes32 nextRoot);
    function verifySNARKs(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[] memory input) public view returns (bool);
}
