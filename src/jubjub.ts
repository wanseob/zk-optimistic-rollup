import { Hex, hexToBytes, toBN } from 'web3-utils';

import { eddsa, ec as EC } from 'elliptic';
import { Hash, Signer } from 'crypto';
import * as circomlib from 'circomlib';
import * as snarkjs from 'snarkjs';

export namespace BabyJubjub {
  export class Point {
    x: BigInt;
    y: BigInt;
    constructor(x: BigInt, y: BigInt) {
      this.x = snarkjs.bigInt(x);
      this.y = snarkjs.bigInt(y);
      if (!circomlib.babyJub.inCurve([x, y])) {
        throw new Error('Given point is not on the Babyjubjub curve');
      }
    }

    static decode(packed: Hex): Point {
      let point = circomlib.babyJub.unpackPoint(hexToBytes(packed));
      return new Point(point[0], point[1]);
    }

    static generate(n: BigInt): Point {
      return BASE8.mul(n);
    }

    static fromPrivKey(key: Hex): Point {
      let result = circomlib.eddsa.prv2pub(hexToBytes(key));
      return new Point(result[0], result[1]);
    }

    static isOnJubjub(x: BigInt, y: BigInt) {
      return circomlib.babyJub.inCurve([x, y]);
    }

    encode(): Hex {
      return circomlib.babyJub.packPoint([this.x, this.y]);
    }

    add(p: Point): Point {
      let result = circomlib.babyJub.addPoint([this.x, this.y], [p.x, p.y]);
      return new Point(result[0], result[1]);
    }

    mul(n: BigInt): Point {
      let result = circomlib.babyJub.mulPointEscalar([this.x, this.y], snarkjs.bigInt(n));
      return new Point(result[0], result[1]);
    }
  }

  export namespace EdDSA {
    export interface Signature {
      R8: Point;
      S: BigInt;
    }

    export function sign(privKey: Hex, msg: Hex): Signature {
      let result = circomlib.eddsa.signPoseidon(hexToBytes(privKey), msg);
      return {
        R8: new Point(result.R8[0], result.R8[1]),
        S: result.S
      };
    }

    export function verify(msg: Hex, sig: Signature, pubKey: Point): boolean {
      let result = circomlib.eddsa.verifyPoseidon(msg, { R8: [sig.R8.x, sig.R8.y], S: sig.S }, [pubKey.x, pubKey.y]);
      return result;
    }
  }

  export const GENERATOR: Point = new Point(circomlib.babyJub.Generator[0], circomlib.babyJub.Generator[1]);

  export const BASE8: Point = new Point(circomlib.babyJub.Base8[0], circomlib.babyJub.Base8[1]);

  export const ORDER: BigInt = circomlib.babyJub.order;
  export const SUB_ORDER: BigInt = circomlib.babyJub.subOrder;
  export const PRIME: BigInt = circomlib.babyJub.p;
  export const A: BigInt = circomlib.babyJub.A;
  export const D: BigInt = circomlib.babyJub.D;
}
