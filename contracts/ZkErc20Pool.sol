pragma solidity >=0.4.21 <0.6.0;

/**
 */
contract ZkErc20Pool {
    address public controller;
    address public coordinator;
    bytes32 public nullifierTree; // Sparse Merkle Tree
    bytes32 public utxoTree; // Blake2s Merkle Tree
    
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
}
