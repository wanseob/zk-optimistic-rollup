include "../../node_modules/circomlib/circuits/poseidon.circom";

template NoteProof() {
    // Signal definitions
    /** Private inputs */
    signal private input note;  
    signal private input amount;
    signal private input pub_key[2];
    signal private input nft;
    signal private input salt;

    // Constraint definition
    component h = Poseidon(5, 6, 8, 57);   // Constant
    h.inputs[0] <== amount;
    h.inputs[1] <== pub_key[0];
    h.inputs[2] <== pub_key[1];
    h.inputs[3] <== nft;
    h.inputs[4] <== salt;
    note === h.out;
}
