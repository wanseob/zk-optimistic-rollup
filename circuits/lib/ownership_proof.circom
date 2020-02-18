include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";

template OwnershipProof() {
    // Signal definitions
    /** Private inputs */
    signal private input note;  
    signal private input pub_key[2];
    signal private input amount;
    signal private input sig[3];

    // Constraint definition
    // 1. Note should be the has of the public key & the amount
    component h = Poseidon(3, 6, 8, 57);   // Constant
    h.inputs[0] <== amount;
    h.inputs[1] <== pub_key[0];
    h.inputs[2] <== pub_key[1];
    note === h.out;
    // 2. The signature should match with the pub key of the note
    component eddsa = EdDSAPoseidonProof()
    eddsa.enabled <== 1;
    eddsa.R8x <== pub_key[0];
    eddsa.R8y <== pub_key[1];
    eddsa.Ax <== sig[0];
    eddsa.Ay <== sig[1];
    eddsa.S <== sig[2];
    eddsa.M <== note;
}
