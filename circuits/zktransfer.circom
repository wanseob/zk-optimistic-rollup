include "./lib/semaphore-base.circom";

template InclusionProof(depth, item_num) {
    /** Signal definition */
    // Public input signal
    signal input root;
    // Private input signals are the merkle proofs
    signal private input leaves[item_num];
    signal private input siblings[depth - 1][item_num];
    // Output signal will be 0 or 1
    signal output result;

    /** Constraint definition */
}

template NullifyingProof(item_num) {
    // Ownership proof + nullifier proof

    /** Signal definition */
    // Public input signals
    signal input nullifiers[item_num];  
    // Private input signals
    signal private input leaves[item_num];
    /** Constraint definition */
}

template ZkTransfer(tree_depth, in, out) {
    /** Private Signals */
    signal private input leaves[in];
    signal private input inclusion_proofs[tree_depth][in];
    signal private input nullifying_proofs[10][in];
    signal private input utxo_details[4][out];
    /** Public Signals */
    signal input fee;
    signal input roots[in];
    signal input nullifiers[in];
    signal output utxos[out];
    /** Constraints */
    // 1. Inclusion proof of all input UTXOs
    // 2. Nullifying proof of all input UTXOs
    // 3. Generate new utxos
    // 4. Check zero sum proof
}

component main = ZkTransfer(256, 2, 2);
