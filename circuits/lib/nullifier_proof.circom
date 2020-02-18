include "../../node_modules/circomlib/circuits/poseidon.circom";

template NullifierProof() {
    // Signal definitions
    /** Public inputs */
    signal input nullifier;  
    /** Private inputs */
    signal private input note;
    signal private input salt;

    // Constraint definition
    component h = Poseidon(2, 6, 8, 57);   // Constant
    h.inputs[0] <== note;
    h.inputs[1] <== salt;
    nullifier === h.out;
}
