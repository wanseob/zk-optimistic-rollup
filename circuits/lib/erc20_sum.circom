include "../../node_modules/circomlib/circuits/babyjub.circom";
include "./token_to_point.circom";

template ERC20Sum(n) {
    signal input addr[n];
    signal input amount[n];
    signal output out[2];

    component points[n];
    for(var i = 0; i < n; i++) {
        points[i] = TokenToPoint();
        points[i].addr <== addr[i];
        points[i].amount <== amount[i];
    }

    component sum[n + 1];
    sum[0] = BabyAdd();
    sum[0].x1 <== 0;
    sum[0].y1 <== 1;
    sum[0].x2 <== 0;
    sum[0].y2 <== 1;
    for(var i = 1; i < n + 1; i++) {
        sum[i] = BabyAdd();
        sum[i].x1 <== sum[i - 1].xout;
        sum[i].y1 <== sum[i - 1].yout;
        sum[i].x2 <== points[i - 1].out[0];
        sum[i].y2 <== points[i - 1].out[1];
    }

    out[0] <== sum[n].xout;
    out[1] <== sum[n].yout;
}