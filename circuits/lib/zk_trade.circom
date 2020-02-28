include "./note_proof.circom";
include "./inclusion_proof.circom";
include "./nullifier_proof.circom";
include "./utils.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";

/// TODO: change it just like Mimblewimble
template ZkTrade(tree_depth, in, out) {
    /** Private Signals for trade */
    signal private input price; /// amount of price should be transfered from the buyer to the seller 
    signal private input is_selling; ///
    signal private input seller[2]; /// needs signature of the seller for this trade
    signal private input buyer[2]; /// Every new nft including note's owner should be the buyer
    signal private input trading_asset;
    signal private input shared_key;
    
    /** Private Signals */
    signal private input notes[in];
    signal private input amount[in];
    signal private input pub_keys[2][in];
    signal private input salts[in];
    signal private input nfts[in];
    signal private input signatures[3][in];
    signal private input path[in];
    signal private input siblings[tree_depth][in];
    signal private input utxo_amount[out];
    signal private input utxo_pub_keys[2][out];
    signal private input utxo_nfts[out];
    signal private input utxo_salts[out];
    /** Public Signals */
    signal input fee;
    signal input inclusion_references[in];
    signal input nullifiers[in];
    signal input utxos[out];

    /** Constraints */
    component maker[2];
    maker[0] = IfElseThen(1);
    maker[1] = IfElseThen(1);
    maker[0].obj1[0] <== is_selling;
    maker[0].obj2[0] <== 1;
    maker[0].if_v <== seller[0];
    maker[0].else_v <== buyer[0];
    maker[1].obj1[0] <== is_selling;
    maker[1].obj2[0] <== 1;
    maker[1].if_v <== seller[1];
    maker[1].else_v <== buyer[1];

    // 1-1. Taker pays the fee
    var prev_amount_of_maker;
    var next_amount_of_maker;
    component inflow_token_of_maker[in];
    component outflow_token_of_maker[out];
    for(var i = 0; i < in; i++) {
        // Calculate inflow amount of tokens of the maker
        inflow_token_of_maker[i] = IfElseThen(2);
        inflow_token_of_maker[i].obj1[0] <== maker[0].out;
        inflow_token_of_maker[i].obj1[1] <== maker[1].out;
        inflow_token_of_maker[i].obj2[0] <== pub_keys[0][i];
        inflow_token_of_maker[i].obj2[1] <== pub_keys[1][i];
        inflow_token_of_maker[i].if_v <== amount[i];
        inflow_token_of_maker[i].else_v <== 0;
        prev_amount_of_maker += inflow_token_of_maker[i].out;
    }
    for(var i = 0; i < out; i++) {
        // Calculate outflow amount of tokens of the maker
        outflow_token_of_maker[i] = IfElseThen(2);
        outflow_token_of_maker[i].obj1[0] <== maker[0].out;
        outflow_token_of_maker[i].obj1[1] <== maker[1].out;
        outflow_token_of_maker[i].obj2[0] <== pub_keys[0][i];
        outflow_token_of_maker[i].obj2[1] <== pub_keys[1][i];
        outflow_token_of_maker[i].if_v <== utxo_amount[i];
        outflow_token_of_maker[i].else_v <== 0;
        next_amount_of_maker += outflow_token_of_maker[i].out;
    }
    component expected_next_bal_of_maker = IfElseThen(1);
    expected_next_bal_of_maker.obj1[0] <== is_selling;
    expected_next_bal_of_maker.obj2[0] <== 1;
    /// Seller is the maker
    expected_next_bal_of_maker.if_v <== prev_amount_of_maker + price;
    /// Seller is the taker
    expected_next_bal_of_maker.else_v <== prev_amount_of_maker + price - fee;
    expected_next_bal_of_maker.out === next_amount_of_maker

    var inflow_target_nft_of_seller;
    var outflow_target_nft_of_buyer;
    component inflow_nft_filter[in];
    component outflow_nft_filter[in];
    for(var i = 0; i < in; i++) {
        // Check that the seller owned the target nft
        inflow_nft_filter[i] = IfElseThen(3);
        inflow_nft_filter[i].obj1[0] <== seller[0];
        inflow_nft_filter[i].obj1[1] <== seller[1];
        inflow_nft_filter[i].obj1[2] <== trading_asset;
        inflow_nft_filter[i].obj2[0] <== pub_keys[0][i];
        inflow_nft_filter[i].obj2[1] <== pub_keys[1][i];
        inflow_nft_filter[i].obj2[2] <== nfts[i];
        inflow_nft_filter[i].if_v <== 1;
        inflow_nft_filter[i].else_v <== 0;
        inflow_target_nft_of_seller += inflow_nft_filter[i].out;
    }
    for(var i = 0; i < out; i++) {
        // Check that the buyer owns the target nft
        outflow_nft_filter[i] = IfElseThen(3);
        outflow_nft_filter[i].obj1[0] <== buyer[0];
        outflow_nft_filter[i].obj1[1] <== buyer[1];
        outflow_nft_filter[i].obj1[2] <== trading_asset;
        outflow_nft_filter[i].obj2[0] <== utxo_pub_keys[0][i];
        outflow_nft_filter[i].obj2[1] <== utxo_pub_keys[1][i];
        outflow_nft_filter[i].obj2[2] <== utxo_nfts[i];
        outflow_nft_filter[i].if_v <== 1;
        outflow_nft_filter[i].else_v <== 0;
        outflow_target_nft_of_buyer += outflow_nft_filter[i].out;
    }
    inflow_target_nft_of_seller === 1
    outflow_target_nft_of_buyer === 1

    // 1-2. need eddsa from seller for the trade_hash = poseidon(price, buyer[2], trading_asset)
    component spending[in];
    component signing_msg[in];
    component trade_hash[in];
    component ownership_proof[in];
    component nullifier_proof[in];
    component inclusion_proof[in];
    for(var i = 0; i < in; i ++) {
        // 1. Note proof
        spending[i] = NoteProof();
        spending[i].note <== notes[i];
        spending[i].pub_key[0] <== pub_keys[0][i];
        spending[i].pub_key[1] <== pub_keys[1][i];
        spending[i].nft <== nfts[i];
        spending[i].salt <== salts[i];
        spending[i].amount <== amount[i];

        // 2. The signature should match with the pub key of the note
        // Buyer can process this trade using seller's signature
        trade_hash[i] = Poseidon(6, 6, 8, 57);   // Constant
        trade_hash[i].inputs[0] <== spending[i].note;
        trade_hash[i].inputs[1] <== price;
        trade_hash[i].inputs[2] <== trading_asset;
        trade_hash[i].inputs[3] <== buyer[0];
        trade_hash[i].inputs[4] <== buyer[1];
        trade_hash[i].inputs[5] <== shared_key;
        signing_msg[i] = IfElseThen(2);
        signing_msg[i].obj1[0] <== pub_keys[0][i];
        signing_msg[i].obj1[1] <== pub_keys[1][i];
        signing_msg[i].obj2[0] <== seller[0];
        signing_msg[i].obj2[1] <== seller[1];
        signing_msg[i].if_v <== trade_hash[i].out;
        signing_msg[i].else_v <== spending[i].note;
        ownership_proof[i] = EdDSAPoseidonVerifier();
        ownership_proof[i].enabled <== 1;
        ownership_proof[i].R8x <== spending[i].pub_key[0];
        ownership_proof[i].R8y <== spending[i].pub_key[1];
        ownership_proof[i].M <== signing_msg[i].out;
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

    component new_utxos[out];
    for (var i = 0; i < out; i++) {
        // 5. Generate new utxos
        new_utxos[i] = NoteProof();
        new_utxos[i].note <== utxos[i];
        new_utxos[i].pub_key[0] <== utxo_pub_keys[0][i];
        new_utxos[i].pub_key[1] <== utxo_pub_keys[1][i];
        new_utxos[i].nft <== utxo_nfts[i];
        new_utxos[i].salt <== utxo_salts[i];
        new_utxos[i].amount <== utxo_amount[i];
    }
    // 6. Check nft transfers
    var BASE8 = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];
    component prev_nft_mult[in + 1];
    component prev_nft_to_bits[in];
    component next_nft_mult[out + 1];
    component next_nft_to_bits[out];
    var prev_nft_sum;
    var next_nft_sum;
    var inflow;
    var outflow;


    // 7. Check zero sum & nfts' non-fungibility
    prev_nft_mult[0] = EscalarMulAny(2);
    prev_nft_mult[0].e[0] <== 1;
    prev_nft_mult[0].e[1] <== 0;
    prev_nft_mult[0].p[0] <== BASE8[0];
    prev_nft_mult[0].p[1] <== BASE8[1];
    next_nft_mult[0] = EscalarMulAny(2);
    next_nft_mult[0].e[0] <== 1;
    next_nft_mult[0].e[1] <== 0;
    next_nft_mult[0].p[0] <== BASE8[0];
    next_nft_mult[0].p[1] <== BASE8[1];
    for ( var i = 0; i < in; i++) {
        inflow += amount[i];
        prev_nft_sum += nfts[i];
        prev_nft_to_bits[i] = NFTtoBits(253);
        prev_nft_to_bits[i].nft <== nfts[i];
        prev_nft_mult[i + 1] = EscalarMulAny(253);
        for(var j = 0; j < 253; j++) {
            prev_nft_mult[i + 1].e[j] <== prev_nft_to_bits[i].out[j]
        }
        prev_nft_mult[i + 1].p[0] <== prev_nft_mult[i].out[0]
        prev_nft_mult[i + 1].p[1] <== prev_nft_mult[i].out[1]
    }
    for ( var i = 0; i < out; i++) {
        outflow += utxo_amount[i];
        next_nft_sum += utxo_nfts[i];
        next_nft_to_bits[i] = NFTtoBits(253);
        next_nft_to_bits[i].nft <== utxo_nfts[i];
        next_nft_mult[i + 1] = EscalarMulAny(253);
        for(var j = 0; j < 253; j++) {
            next_nft_mult[i + 1].e[j] <== next_nft_to_bits[i].out[j]
        }
        next_nft_mult[i + 1].p[0] <== next_nft_mult[i].out[0]
        next_nft_mult[i + 1].p[1] <== next_nft_mult[i].out[1]
    }
    outflow += fee;

    component no_money_printed = ForceEqualIfEnabled();
    no_money_printed.enabled <== 1;
    no_money_printed.in[0] <== inflow;
    no_money_printed.in[1] <== outflow;

    component nfts_are_non_fungible[3];
    nfts_are_non_fungible[0] = ForceEqualIfEnabled();
    nfts_are_non_fungible[1] = ForceEqualIfEnabled();
    nfts_are_non_fungible[2] = ForceEqualIfEnabled();
    /// Multiplication of all nfts in the used notes should equal
    /// to the mult of the all nfts in the new uxtos.
    /// If nft is zero, mult 1.
    nfts_are_non_fungible[0].enabled <== 1;
    nfts_are_non_fungible[0].in[0] <== prev_nft_mult[in].out[0];
    nfts_are_non_fungible[0].in[1] <== prev_nft_mult[in].out[1];
    nfts_are_non_fungible[1].enabled <== 1;
    nfts_are_non_fungible[1].in[0] <== next_nft_mult[out].out[0];
    nfts_are_non_fungible[1].in[1] <== next_nft_mult[out].out[1];
    /// Sum of all nfts in the used notes should equal
    /// to the sum of the all nfts in the new uxtos.
    nfts_are_non_fungible[2].enabled <== 1;
    nfts_are_non_fungible[2].in[0] <== prev_nft_sum;
    nfts_are_non_fungible[2].in[1] <== next_nft_sum;
}
