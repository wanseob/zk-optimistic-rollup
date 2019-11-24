include "./lib/semaphore-base.circom";

template InclusionProver(depth, item_num) {
    /** Signal definition */
    // Public input signal
    signal input root;
    // Private input signals are the merkle proofs
    signal private leaves[item_num];
    signal private siblings[depth - 1][item_num];
    // Output signal will be 0 or 1
    signal output result;

    /** Constraint definition */
}

template NullifyingProver(item_num) {
    // Ownership proof + nullifier proof

    /** Signal definition */
    // Public input signals
    signal private leaves[item_num];
    signal public nullifiers[item_num];  
    /** Constraint definition */
}

template ZkTransfer(tree_depth, in, out) {
    /** Private Signals */
    signal private input leaves[in];
    signal private input inclusion_proofs[tree_depth][in];
    signal private input nullifying_proofs[10][in];
    signal private input utxo_details[4][out];
    /** Public Signals */
    signal public input fee;
    signal public input roots[in];
    signal public input nullifiers[in];
    signal public output utxos[out];
    /** Constraints */
    // 1. Inclusion proof of all input UTXOs
    // 2. Nullifying proof of all input UTXOs
    // 3. Generate new utxos
    // 4. Check zero sum proof
}

component main = ZkTransfer();
