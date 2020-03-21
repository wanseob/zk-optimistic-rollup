import { BabyJubjub } from './jubjub';
import { Field } from './field';
import * as circomlib from 'circomlib';

export interface EdDSA {
  R8: BabyJubjub.Point;
  S: Field;
}

export function sign(msg: Field, privKey: string): EdDSA {
  let signature = circomlib.eddsa.signPoseidon(privKey, msg.val);
  return {
    R8: BabyJubjub.Point.from(signature.R8[0], signature.R8[1]),
    S: Field.from(signature.S)
  };
}
