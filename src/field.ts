import * as snarkjs from 'snarkjs';
import { Hex, toBN, padLeft } from 'web3-utils';

export class Field {
  val: snarkjs.bigInt;

  constructor(val: BigInt) {
    this.val = snarkjs.bigInt(val);
    if (this.val >= snarkjs.bn128.r) {
      throw Error('Exceeds SNARK field: ' + this.val.toString());
    }
  }

  static from(x: any): Field {
    if (x === undefined) return new Field(BigInt(0));
    else return new Field(x);
  }

  static fromBuffer(buff: Buffer): Field {
    return Field.from(toBN(buff.toString('hex')));
  }

  static leInt2Buff(n: BigInt, len: number): Buffer {
    return snarkjs.bigInt.leInt2Buff(n, len);
  }

  static leBuff2int(buff: Buffer): Field {
    return Field.from(snarkjs.bigInt.leBuff2int(buff));
  }

  toBuffer(n?: number): Buffer {
    if (!this.val.shr(n * 8).isZero()) throw Error('Not enough buffer size');
    let hex = n ? padLeft(this.val.toString(16), 2 * n) : this.val.toString(16);
    return Buffer.from(hex, 'hex');
  }

  shr(n: number): Field {
    return Field.from(this.val.shr(n));
  }

  isZero(): boolean {
    return this.val.isZero();
  }

  toString(): string {
    return this.val.toString();
  }

  toHex(): Hex {
    return '0x' + this.val.toString(16);
  }

  equal(n: Field): boolean {
    return this.val === n.val;
  }

  add(n: Field): Field {
    let newVal = this.val + n.val;
    if (newVal < this.val) {
      throw Error('Field overflow');
    }
    return Field.from(this.val + n.val);
  }

  sub(n: Field): Field {
    let newVal = this.val - n.val;
    if (newVal > this.val) {
      throw Error('Field underflow');
    }
    return Field.from(this.val + n.val);
  }

  greaterThan(n: Field): boolean {
    return this.val > n.val;
  }

  gte(n: Field): boolean {
    return this.val >= n.val;
  }
}
