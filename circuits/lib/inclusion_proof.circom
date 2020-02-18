include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template BranchNode() {
    signal input left;
    signal input right;
    signal output parent;

    component hasher = Poseidon(2, 6, 8, 57);   // Constant
    hasher.inputs[0] <== left;
    hasher.inputs[1] <== right;

    parent <== hasher.out;
}

template InclusionProof(depth) {
    // Signal definitions
    /** Public inputs */
    signal input root;
    /** Private inputs */
    signal private input leaf;
    signal private input path;
    signal private input siblings[depth];
    /** Outputs */
    signal output result;

    component path_bits = Num2Bits(depth);
    path_bits.in <== path;

    // Constraint definition
    signal nodes[depth + 1];
    component branch_nodes[depth];
    nodes[0] <== leaf;
    for (var level = 0; level < depth; level++) {
        branch_nodes[level] = BranchNode();
        // If the bitified path_bits is 0, the branch node has a left sibling
        branch_nodes[level].left <-- path_bits.out[level] == 0 ? nodes[level] : siblings[level];
        branch_nodes[level].right <-- path_bits.out[level] == 0 ? siblings[level] : nodes[level];
        nodes[level+1] <== branch_nodes[level].parent;
    }
    nodes[depth] === root;
}