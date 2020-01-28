pragma solidity >= 0.6.0;

contract Configurated {
    /**
     * Constants to manage this layer2 system.
     * Rationales: https://github.com/wilsonbeam/zk-optimistic-rollup/wiki
     */
    uint public CHALLENGE_PERIOD = 7 days;
    uint public CHALLENGE_LIMIT = 8000000;
    uint public MINIMUM_STAKE = 32 ether;
    uint public REF_DEPTH = 128;
    uint public POOL_SIZE = (1 << 31);
}
