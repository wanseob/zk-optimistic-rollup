import { Field } from './field';
import { Hex, soliditySha3 } from 'web3-utils';
import { Queue } from './utils';
import { Outflow, Inflow, PublicData } from './transaction';
import * as snarkjs from 'snarkjs';

export interface SNARK {
  pi_a: Field[];
  pi_b: Field[][];
  pi_c: Field[];
}

export class ZkTransaction {
  inflow: Inflow[];
  outflow: Outflow[];
  fee: Field;
  proof?: SNARK;
  swap?: Field;
  memo?: Buffer;
  _hash?: Hex;
  _size?: number;

  constructor({ inflow, outflow, fee, proof, swap, memo }: { inflow: Inflow[]; outflow: Outflow[]; fee: Field; proof?: SNARK; swap?: Field; memo?: Buffer }) {
    this.inflow = inflow;
    this.outflow = outflow;
    this.fee = fee;
    this.proof = proof;
    this.swap = swap;
    this.memo = memo;
  }

  encode(): Buffer {
    if (!this.proof) throw Error('SNARK does not exist');
    return Buffer.concat([
      Uint8Array.from([this.inflow.length]),
      ...this.inflow.map(inflow => Buffer.concat([inflow.root.toBuffer(32), inflow.nullifier.toBuffer(32)])),
      Uint8Array.from([this.outflow.length]),
      ...this.outflow.map(outflow =>
        Buffer.concat([
          outflow.note.toBuffer(32),
          outflow.outflowType.toBuffer(1),
          outflow.data
            ? Buffer.concat([
                outflow.data.to.toBuffer(20),
                outflow.data.eth.toBuffer(32),
                outflow.data.tokenAddr.toBuffer(20),
                outflow.data.erc20Amount.toBuffer(32),
                outflow.data.nft.toBuffer(32),
                outflow.data.fee.toBuffer(32)
              ])
            : Buffer.from([])
        ])
      ),
      this.fee.toBuffer(32),
      this.proof.pi_a[0].toBuffer(32),
      this.proof.pi_a[1].toBuffer(32),
      this.proof.pi_b[0][0].toBuffer(32),
      this.proof.pi_b[0][1].toBuffer(32),
      this.proof.pi_b[1][0].toBuffer(32),
      this.proof.pi_b[1][1].toBuffer(32),
      this.proof.pi_c[0].toBuffer(32),
      this.proof.pi_c[1].toBuffer(32),
      Uint8Array.from([this.swap ? (1 << 0) + (this.memo ? 1 << 1 : 0 << 1) : (0 << 0) + (this.memo ? 1 << 1 : 0 << 1)]), // b'11' => tx has swap & memo, b'00' => no swap & no memo
      this.swap ? this.swap.toBuffer(32) : Buffer.from([]),
      this.memo ? this.memo.slice(0, 81) : Buffer.from([])
    ]);
  }

  hash(): Hex {
    if (!this._hash) {
      let encodePacked = Buffer.concat([
        ...this.inflow.map(inflow => {
          return Buffer.concat([inflow.root.toBuffer(32), inflow.nullifier.toBuffer(32)]);
        }),
        ...this.outflow.map(outflow => {
          return Buffer.concat([
            outflow.note.toBuffer(32),
            outflow.data ? outflow.data.to.toBuffer(20) : Buffer.from([]),
            outflow.data ? outflow.data.eth.toBuffer(32) : Buffer.from([]),
            outflow.data ? outflow.data.tokenAddr.toBuffer(20) : Buffer.from([]),
            outflow.data ? outflow.data.erc20Amount.toBuffer(32) : Buffer.from([]),
            outflow.data ? outflow.data.nft.toBuffer(32) : Buffer.from([]),
            outflow.data ? outflow.data.fee.toBuffer(32) : Buffer.from([])
          ]);
        }),
        this.swap ? this.swap.toBuffer(32) : Buffer.alloc(32),
        this.proof.pi_a[0].toBuffer(32),
        this.proof.pi_a[1].toBuffer(32),
        this.proof.pi_b[0][0].toBuffer(32),
        this.proof.pi_b[0][1].toBuffer(32),
        this.proof.pi_b[1][0].toBuffer(32),
        this.proof.pi_b[1][1].toBuffer(32),
        this.proof.pi_c[0].toBuffer(32),
        this.proof.pi_c[0].toBuffer(32),
        this.fee.toBuffer(32)
      ]);
      this._hash = soliditySha3(encodePacked.toString('hex'));
    }
    return this._hash;
  }
  size(): number {
    if (!this._size) {
      this._size = this.encode().length;
    }
    return this._size;
  }

  signals(): bigint[] {
    let signals = [
      this.fee.val,
      this.swap ? this.swap.val : Field.zero.val,
      ...this.inflow.map(inflow => inflow.root.val),
      ...this.inflow.map(inflow => inflow.nullifier.val),
      ...this.outflow.map(outflow => outflow.note.val),
      ...this.outflow.map(outflow => outflow.outflowType.val),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.to.val : Field.zero.val)),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.eth.val : Field.zero.val)),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.tokenAddr.val : Field.zero.val)),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.erc20Amount.val : Field.zero.val)),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.nft.val : Field.zero.val)),
      ...this.outflow.map(outflow => (outflow.data ? outflow.data.fee.val : Field.zero.val))
    ];
    return signals;
  }

  static decode(buff: Buffer): ZkTransaction {
    let zkTx: ZkTransaction = Object.create(ZkTransaction.prototype);
    let queue = new Queue(buff);
    // Inflow
    let n_i = queue.dequeue(1)[0];
    zkTx.inflow = [];
    for (let i = 0; i < n_i; i++) {
      zkTx.inflow.push({
        root: Field.fromBuffer(queue.dequeue(32)),
        nullifier: Field.fromBuffer(queue.dequeue(32))
      });
    }
    // Outflow
    let n_o = queue.dequeue(1)[0];
    zkTx.outflow = [];
    for (let i = 0; i < n_o; i++) {
      let note = Field.fromBuffer(queue.dequeue(32));
      let outflowType = Field.from(queue.dequeue(1)[0]);
      let data: PublicData = undefined;
      if (!outflowType.isZero()) {
        data = {
          to: Field.fromBuffer(queue.dequeue(20)),
          eth: Field.fromBuffer(queue.dequeue(32)),
          tokenAddr: Field.fromBuffer(queue.dequeue(20)),
          erc20Amount: Field.fromBuffer(queue.dequeue(32)),
          nft: Field.fromBuffer(queue.dequeue(32)),
          fee: Field.fromBuffer(queue.dequeue(32))
        };
      }
      zkTx.outflow.push({
        note,
        outflowType,
        data
      });
    }
    // Fee
    zkTx.fee = Field.fromBuffer(queue.dequeue(32));
    // SNARK
    zkTx.proof = {
      pi_a: [Field.fromBuffer(queue.dequeue(32)), Field.fromBuffer(queue.dequeue(32))],
      pi_b: [
        [Field.fromBuffer(queue.dequeue(32)), Field.fromBuffer(queue.dequeue(32))],
        [Field.fromBuffer(queue.dequeue(32)), Field.fromBuffer(queue.dequeue(32))]
      ],
      pi_c: [Field.fromBuffer(queue.dequeue(32)), Field.fromBuffer(queue.dequeue(32))]
    };
    // Swap
    let swapAndMemo = queue.dequeue(1)[0];
    if (swapAndMemo & (1 << 0)) {
      zkTx.swap = Field.fromBuffer(queue.dequeue(32));
    }
    // Memo
    if (swapAndMemo & (1 << 1)) {
      zkTx.memo = queue.dequeue(81);
    }
    zkTx._size = buff.length;
    return zkTx;
  }

  circomProof(): { pi_a: bigint[]; pi_b: bigint[][]; pi_c: bigint[]; protocol: string } {
    return {
      pi_a: [...this.proof.pi_a.map(f => f.val), snarkjs.bigInt(1)],
      pi_b: [...this.proof.pi_b.map(arr => arr.map(f => f.val)), [snarkjs.bigInt(1), snarkjs.bigInt(0)]],
      pi_c: [...this.proof.pi_c.map(f => f.val), snarkjs.bigInt(1)],
      protocol: 'groth'
    };
  }
}
