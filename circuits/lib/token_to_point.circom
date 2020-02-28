include "../../node_modules/circomlib/circuits/escalarmulany.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template TokenToPoint() {
    signal input addr;
    signal input amount;
    signal output out[2];

    var BASE8 = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];

    component generator = EscalarMulAny(160);
    generator.p[0] <== BASE8[0];
    generator.p[1] <== BASE8[1];
    component addr_bits = Num2Bits(160);
    addr_bits.in <== addr;
    for(var i = 0; i < 160; i++) {
        generator.e[i] <== addr_bits.out[i];
    }

    component mult = EscalarMulAny(254);
    mult.p[0] <== generator.out[0];
    mult.p[1] <== generator.out[1];
    component amount_bits = Num2Bits(254);
    amount_bits.in <== amount;
    for(var i = 0; i < 254; i++) {
        mult.e[i] <== amount_bits.out[i];
    }
    out[0] <== mult.out[0];
    out[1] <== mult.out[1];
}