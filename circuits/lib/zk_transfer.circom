include "./utils.circom";
include "./inclusion_proof.circom";
include "./nullifier_proof.circom";
include "./erc20_sum.circom";
include "./non_fungible.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template ZkTransfer(tree_depth, n_i, n_o) {
    /** Private Signals */
    // Details of spending notes
    // note[0]: ETH value
    // note[1]: Pub Key x
    // note[2]: Pub Key y
    // note[3]: salt
    // note[4]: token
    // note[5]: amount if token is ERC20
    // note[6]: nft id if token is ERC721

    // Spending notes
    signal private input spending_note[7][n_i];
    signal private input signatures[3][n_i];
    signal private input note_index[n_i];
    signal private input siblings[tree_depth][n_i];
    // New notes
    signal private input new_note[7][n_o];
    // Bindings: salt_a, pk_b[2], token, order[2], H_b[2]
    // Please see private order matching for zk atomic swap
    signal private input binding_factors[8];

    /** Public Signals */
    signal input binding[2];
    signal input fee;
    signal input inclusion_references[n_i];
    signal input nullifiers[n_i];
    signal input new_note_hash[n_o];

    /** Constraints */
    // 6. Check zero sum proof

    /// Calculate spending note hash
    component poseidon_note[n_i];
    for(var i = 0; i < n_i; i ++) {
        poseidon_note[i] = Poseidon(7, 6, 8, 57);   // Constant
        poseidon_note[i].inputs[0] <== spending_note[0][i];
        poseidon_note[i].inputs[1] <== spending_note[1][i];
        poseidon_note[i].inputs[2] <== spending_note[2][i];
        poseidon_note[i].inputs[3] <== spending_note[3][i];
        poseidon_note[i].inputs[4] <== spending_note[4][i];
        poseidon_note[i].inputs[5] <== spending_note[5][i];
        poseidon_note[i].inputs[6] <== spending_note[6][i];
    }

    /// Nullifier proof
    component spending_nullifier[n_i];
    for(var i = 0; i < n_i; i ++) {
        spending_nullifier[i] = Poseidon(2, 6, 8, 57);   // Constant
        spending_nullifier[i].inputs[0] <== poseidon_note[i].out;
        spending_nullifier[i].inputs[1] <== note_index[i];
        spending_nullifier[i].out === nullifiers[i];
    }

    /// Ownership proof
    component ownership_proof[n_i];
    for(var i = 0; i < n_i; i ++) {
        ownership_proof[i] = EdDSAPoseidonVerifier();
        ownership_proof[i].enabled <== 1;
        ownership_proof[i].M <== spending_nullifier[i].out;
        ownership_proof[i].R8x <== spending_note[1][i];
        ownership_proof[i].R8y <== spending_note[2][i];
        ownership_proof[i].Ax <== signatures[0][i];
        ownership_proof[i].Ay <== signatures[1][i];
        ownership_proof[i].S <== signatures[2][i];
    }

    /// Inclusion proof
    component inclusion_proof[n_i];
    for(var i = 0; i < n_i; i ++) {
        inclusion_proof[i] = InclusionProof(tree_depth);
        inclusion_proof[i].root <== inclusion_references[i];
        inclusion_proof[i].leaf <== poseidon_note[i].out;
        inclusion_proof[i].path <== note_index[i];
        for(var j = 0; j < tree_depth; j++) {
            inclusion_proof[i].siblings[j] <== siblings[j][i];
        }
    }

    /// New note hash proof
    component poseidon_new_note[n_o];
    for(var i = 0; i < n_o; i ++) {
        poseidon_new_note[i] = Poseidon(7, 6, 8, 57);   // Constant
        poseidon_new_note[i].inputs[0] <== new_note[0][i];
        poseidon_new_note[i].inputs[1] <== new_note[1][i];
        poseidon_new_note[i].inputs[2] <== new_note[2][i];
        poseidon_new_note[i].inputs[3] <== new_note[3][i];
        poseidon_new_note[i].inputs[4] <== new_note[4][i];
        poseidon_new_note[i].inputs[5] <== new_note[5][i];
        poseidon_new_note[i].inputs[6] <== new_note[6][i];
        poseidon_new_note[i].out === new_note_hash[i];
    }

    /// Zero sum proof of ETH
    var eth_inflow;
    var eth_outflow;
    for ( var i = 0; i < n_i; i++) {
        eth_inflow += spending_note[0][i];
    }
    for ( var i = 0; i < n_o; i++) {
        eth_outflow += new_note[0][i];
    }
    eth_inflow === eth_outflow;

    ///  Only one of ERC20 or ERC721 exists
    for(var i = 0; i < n_i; i ++) {
        spending_note[5][i]*spending_note[6][i] === 0;
    }
    for(var i = 0; i < n_o; i ++) {
        new_note[5][i]*new_note[6][i] === 0;
    }


    /// Zero sum proof of ERC20
    component inflow_erc20 = ERC20Sum(n_i);
    component outflow_erc20 = ERC20Sum(n_o);
    for ( var i = 0; i < n_i; i++) {
        inflow_erc20.addr[i] <== spending_note[4][i];
        inflow_erc20.amount[i] <== spending_note[5][i];
    }
    for ( var i = 0; i < n_o; i++) {
        outflow_erc20.addr[i] <== new_note[4][i];
        outflow_erc20.amount[i] <== new_note[5][i];
    }
    inflow_erc20.out[0] === outflow_erc20.out[0];
    inflow_erc20.out[1] === outflow_erc20.out[1];

    /// Non fungible proof of ERC721
    component non_fungible = NonFungible(n_i, n_o);
    for(var i = 0; i < n_i; i++) {
        non_fungible.prev_token_addr[i] <== spending_note[4][i]; 
        non_fungible.prev_token_nft[i] <== spending_note[6][i];
    }
    for(var i = 0; i < n_o; i++) {
        non_fungible.post_token_addr[i] <== new_note[4][i]; 
        non_fungible.post_token_nft[i] <== new_note[6][i];
    }

    /// Binding proof
    /// PK
    /// token addr 
    /// swap amount
    /// MPC proof
}
