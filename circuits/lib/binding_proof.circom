template BindingProof() {
    /// Binding proof
    /// PK
    /// token addr 
    /// swap amount
    /// MPC proof
    signal input pk[2];
    signal input position; // 1: eth 2: erc20 3: erc721
    signal input swap_token;
    signal input swap_amount[3];
    signal input note[7];
    signal output out;

    (1 - position) * (2 - position) * (3 - position) === 0;
    component amount = IfElseThen(1);
    amount.obj1[0] <== position;
    amount.obj2[0] <== 0;
    amount.if_v <== swap_amount[0];
    amount.else_v <== swap_amount[1];
    component eth_amount = IfElseThen(1);
    eth_amount.obj1[0] <== position;
    eth_amount.obj2[0] <== 1;
    eth_amount.if_v <== swap_amount[0];
    eth_amount.else_v <== 0;
    component token_amount = IfElseThen(1);
    token_amount.obj1[0] <== position;
    token_amount.obj2[0] <== 2;
    token_amount.if_v <== swap_amount[1];
    token_amount.else_v <== 0;
    component nft_id = IfElseThen(1);
    token_amount.obj1[0] <== position;
    token_amount.obj2[0] <== 3;
    token_amount.if_v <== swap_amount[2];
    token_amount.else_v <== 0;

    note[0] === eth_amount.out;
    note[1] === pk[0];
    note[2] === pk[1];
    // note[3] === any salt;
    note[4] === swap_token;
    note[5] === token_amount.out;
    note[6] === token_amount.out;


    component counter[n];
    signal intermediates[n+1];
    intermediates[0] <== 0;
    for(var i = 0; i < n; i++) {
        counter[i] = IfElseThen(2);
        counter[i].obj1[0] <== addr;
        counter[i].obj1[1] <== nft;
        counter[i].obj2[0] <== comp_addr[i];
        counter[i].obj2[1] <== comp_nft[i];
        counter[i].if_v <== intermediates[i] + 1;
        counter[i].else_v <== intermediates[i];
        counter[i].out ==> intermediates[i+1];
    }
    out <== intermediates[n];
}

template NonFungible(n_i, n_o) {
    signal input prev_token_addr[n_i];
    signal input prev_token_nft[n_i];
    signal input post_token_addr[n_o];
    signal input post_token_nft[n_o];

    component token_count_1[n_i];
    component expected_count_1[n_i];
    for(var i = 0; i < n_i; i++) {
        expected_count_1[i] = IfElseThen(1);
        expected_count_1[i].obj1[0] <== prev_token_nft[i];
        expected_count_1[i].obj2[0] <== 0;
        expected_count_1[i].if_v <== 0;
        expected_count_1[i].else_v <== 1;

        token_count_1[i] = CountSameNFT(n_o);
        token_count_1[i].addr <== prev_token_addr[i];
        token_count_1[i].nft <== prev_token_nft[i];
        for(var j = 0; j < n_o; j++) {
            token_count_1[i].comp_addr[j] <== post_token_addr[j];
            token_count_1[i].comp_nft[j] <== post_token_nft[j];
        }
        token_count_1[i].out === expected_count_1[i].out;
    }

    component token_count_2[n_o];
    component expected_count_2[n_o];
    for(var i = 0; i < n_o; i++) {
        expected_count_2[i] = IfElseThen(1);
        expected_count_2[i].obj1[0] <== post_token_nft[i];
        expected_count_2[i].obj2[0] <== 0;
        expected_count_2[i].if_v <== 0;
        expected_count_2[i].else_v <== 1;

        token_count_2[i] = CountSameNFT(n_o);
        token_count_2[i].addr <== post_token_addr[i];
        token_count_2[i].nft <== post_token_nft[i];
        for(var j = 0; j < n_o; j++) {
            token_count_2[i].comp_addr[j] <== prev_token_addr[j];
            token_count_2[i].comp_nft[j] <== prev_token_nft[j];
        }
        token_count_2[i].out === expected_count_2[i].out;
    }
}