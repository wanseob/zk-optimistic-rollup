include "./note_proof.circom";
include "./ownership_proof.circom";
include "./inclusion_proof.circom";
include "./nullifier_proof.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template ZkMigration(tree_depth, in) {
    /** Private Signals */
    signal private input notes[in];
    signal private input amount[in];
    signal private input pub_keys[2][in];
    signal private input salts[in];
    signal private input signatures[3][in];
    signal private input path[in];
    signal private input siblings[tree_depth][in];
    signal private input migration_pub_keys[2];
    signal private input migration_salt;
    /** Public Signals */
    signal input migration_note;
    signal input migration_dest;
    signal input migration_amount;
    signal input migration_fee;
    signal input fee;
    signal input inclusion_references[in];
    signal input nullifiers[in];
    /** Constraints */
    // 1. Note proof
    // 2. Ownership proof
    // 3. Inclusion proof of all input UTXOs
    // 4. Nullifying proof of all input UTXOs
    // 5. Generate new migration note
    // 6. Check zero sum proof
    
    component spending[in];
    component ownership_proof[in];
    component nullifier_proof[in];
    component inclusion_proof[in];
    for(var i = 0; i < in; i ++) {
        // 1. Note proof
        spending[i] = NoteProof();
        spending[i].note <== notes[i];
        spending[i].pub_key[0] <== pub_keys[0][i];
        spending[i].pub_key[1] <== pub_keys[1][i];
        spending[i].salt <== salts[i];
        spending[i].amount <== amount[i];

        // 2. The signature should match with the pub key of the note
        ownership_proof[i] = EdDSAPoseidonVerifier();
        ownership_proof[i].enabled <== 1;
        ownership_proof[i].R8x <== spending[i].pub_key[0];
        ownership_proof[i].R8y <== spending[i].pub_key[1];
        ownership_proof[i].M <== spending[i].note;
        ownership_proof[i].Ax <== signatures[0][i];
        ownership_proof[i].Ay <== signatures[1][i];
        ownership_proof[i].S <== signatures[2][i];

        // 2. Nullifier proof
        nullifier_proof[i] = NullifierProof();
        nullifier_proof[i].nullifier <== nullifiers[i];
        nullifier_proof[i].note <== notes[i];
        nullifier_proof[i].salt <== salts[i];

        // 4. Inclusion proof
        inclusion_proof[i] = InclusionProof(tree_depth);
        inclusion_proof[i].root <== inclusion_references[i];
        inclusion_proof[i].leaf <== notes[i];
        inclusion_proof[i].path <== path[i];
        for(var j = 0; j < tree_depth; j++) {
            inclusion_proof[i].siblings[j] <== siblings[j][i];
        }
    }

    // 5. Generate new salt to prevent the coordinator manipulate the
    // destination, amount and the fee.
    component poseidon = Poseidon(4, 6, 8, 57);
    poseidon.inputs[0] <== migration_dest;
    poseidon.inputs[1] <== migration_amount;
    poseidon.inputs[2] <== migration_fee;
    poseidon.inputs[3] <== migration_salt;

    // 6. Generate new migration
    component migration = NoteProof();
    migration.note <== migration_note;
    migration.amount <== migration_amount;
    migration.pub_key[0] <== migration_pub_keys[0];
    migration.pub_key[1] <== migration_pub_keys[1];
    migration.salt <== poseidon.out;

    // 7. Check zero sum
    var inflow;
    for ( var i = 0; i < in; i++) {
        inflow += amount[i]
    }
    var outflow;
    outflow += migration_amount;
    outflow += fee;
    outflow += migration_fee;
    inflow === outflow;
}
