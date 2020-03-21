import { UTXO } from './utxo';
import { Field } from './field';
import { BabyJubjub } from './jubjub';
import { UTXOGrove, MerkleProof } from './tree';
import { EdDSA, sign } from './eddsa';
import * as snarkjs from 'snarkjs';

export interface Transaction {
  inflow: UTXO[];
  outflow: UTXO[];
  swap?: Field;
  fee: Field;
}

export class ZkTransaction {
  inflow: Inflow[];
  outflow: Outflow[];
  fee: Field;
  proof?: SNARK;
  swap?: Field;
  memo?: Buffer;

  constructor(inflow: Inflow[], outflow: Outflow[], fee: Field, proof?: SNARK, swap?: Field, memo?: Buffer) {
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
                outflow.data.token.toBuffer(20),
                outflow.data.amount.toBuffer(32),
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

  static decode(buff: Buffer): ZkTransaction {
    let zkTx: ZkTransaction = Object.create(ZkTransaction.prototype);
    let queue = new Queue(buff);
    let n_i = queue.dequeue(1)[0];
    zkTx.inflow = [];
    for (let i = 0; i < n_i; i++) {
      zkTx.inflow.push({
        root: Field.from(queue.dequeue(32)),
        nullifier: Field.from(queue.dequeue(32))
      });
    }
    let n_o = queue.dequeue(1)[0];
    zkTx.outflow = [];
    for (let i = 0; i < n_o; i++) {
      let note = Field.from(queue.dequeue(32));
      let outflowType = Field.from(queue.dequeue(1)[0]);
      let data: PublicData = undefined;
      if (!outflowType.isZero()) {
        data.to = Field.from(queue.dequeue(20));
        data.eth = Field.from(queue.dequeue(32));
        data.token = Field.from(queue.dequeue(20));
        data.amount = Field.from(queue.dequeue(32));
        data.nft = Field.from(queue.dequeue(32));
        data.fee = Field.from(queue.dequeue(32));
      }
      zkTx.outflow.push({
        note,
        outflowType,
        data
      });
    }
    let swapAndMemo = queue.dequeue(1)[0];
    if (swapAndMemo & (1 << 0)) {
      zkTx.swap = Field.from(queue.dequeue(32));
    }
    if (swapAndMemo & (1 << 1)) {
      zkTx.memo = queue.dequeue(81);
    }
    return zkTx;
  }
}

class Queue {
  buffer: Buffer;
  cursor: number;
  constructor(buffer: Buffer) {
    this.buffer;
    this.cursor = 0;
  }
  dequeue(n: number): Buffer {
    let dequeued = this.buffer.slice(this.cursor, this.cursor + n);
    this.cursor += n;
    return dequeued;
  }
}

export interface Inflow {
  nullifier: Field;
  root: Field;
}

export interface Outflow {
  note: Field;
  outflowType: Field;
  data?: PublicData;
}

export interface PublicData {
  to: Field;
  eth: Field;
  token: Field;
  amount: Field;
  nft: Field;
  fee: Field;
}

export interface SNARK {
  pi_a: Field[];
  pi_b: Field[][];
  pi_c: Field[];
}

export class Asset {
  eth: Field;
  erc20: {
    [addr: string]: Field;
  };
  erc721: {
    [addr: string]: Field[];
  };

  static getEtherFrom(utxos: UTXO[]): Field {
    let sum = Field.from(0);
    for (let item of utxos) {
      sum = sum.add(item.eth);
    }
    return sum;
  }

  static getERC20sFrom(utxos: UTXO[]): { [addr: string]: Field } {
    let erc20 = {};
    for (let item of utxos) {
      let addr = item.token.toHex();
      if (!item.amount.isZero() && item.nft.isZero()) {
        let prev = erc20[addr] ? erc20[addr] : Field.from(0);
        erc20[item.token.val] = prev.add(item.amount);
      }
    }
    return erc20;
  }

  static getNFTsFrom(utxos: UTXO[]): { [addr: string]: Field[] } {
    let erc721 = {};
    for (let item of utxos) {
      let addr = item.token.toHex();
      if (item.amount.isZero() && !item.nft.isZero()) {
        if (!erc721[addr]) {
          erc721[addr] = [];
        }
        erc721[addr].push(item.nft);
      }
    }
    return erc721;
  }

  static from(utxos: UTXO[]): Asset {
    return {
      eth: Asset.getEtherFrom(utxos),
      erc20: Asset.getERC20sFrom(utxos),
      erc721: Asset.getNFTsFrom(utxos)
    };
  }
}

export class TxBuilder {
  spendables: UTXO[];
  sendings: UTXO[];
  fee: Field;
  swap?: Field;

  changeTo: BabyJubjub.Point;
  constructor(pubKey: BabyJubjub.Point) {
    this.changeTo = pubKey;
  }

  setFee(fee: Field): TxBuilder {
    this.fee = fee;
    return this;
  }

  addSpendable(utxo: UTXO): TxBuilder {
    this.spendables.push(utxo);
    return this;
  }
  addSpendables(...utxos: UTXO[]): TxBuilder {
    utxos.forEach(utxo => this.spendables.push(utxo));
    return this;
  }

  /**
   * This will throw underflow Errof when it does not have enough ETH for fee
   */
  spendable(): Asset {
    let asset = Asset.from(this.spendables);
    asset.eth = asset.eth.sub(this.fee);
    return asset;
  }

  sendEtherTo(amount: Field, to: BabyJubjub.Point): TxBuilder {
    this.sendings.push(UTXO.newEtherNote(amount, to));
    return this;
  }

  sendERC20To(addr: Field, amount: Field, to: BabyJubjub.Point, eth?: Field): TxBuilder {
    this.sendings.push(UTXO.newERC20Note(eth ? eth : 0, addr, amount, to));
    return this;
  }

  sendNFTTo(addr: Field, id: Field, to: BabyJubjub.Point, eth?: Field): TxBuilder {
    this.sendings.push(UTXO.newNFTNote(eth ? eth : 0, addr, id, to));
    return this;
  }

  migrateOutEther(amount: Field, to: Field): TxBuilder {
    return this;
  }

  swapForEther(amount: Field): TxBuilder {
    this.swap = UTXO.newEtherNote(amount, this.changeTo).hash();
    return this;
  }

  swapForERC20(addr: Field, amount: Field): TxBuilder {
    this.swap = UTXO.newERC20Note(0, addr, amount, this.changeTo).hash();
    return this;
  }

  swapForToken(addr: Field, nft: Field): TxBuilder {
    this.swap = UTXO.newNFTNote(0, addr, nft, this.changeTo).hash();
    return this;
  }

  build(): Transaction {
    let spendables: UTXO[] = [...this.spendables];
    let spendings: UTXO[] = [];

    let sendingAmount = Asset.from(this.sendings);

    Object.keys(sendingAmount.erc20).forEach(addr => {
      let targetAmount: Field = sendingAmount.erc20[addr];
      let sameERC20UTXOs: UTXO[] = this.spendables.filter(utxo => utxo.token.toHex() === addr).sort((a, b) => (a.amount.greaterThan(b.amount) ? 1 : -1));
      for (let utxo of sameERC20UTXOs) {
        if (targetAmount.greaterThan(Asset.from(spendings).erc20[addr])) {
          spendings.push(...spendables.splice(spendables.indexOf(utxo), 1));
        } else {
          break;
        }
      }
      if (targetAmount.greaterThan(Asset.from(spendings).erc20[addr])) {
        throw Error(`Non enough ERC20 token ${addr} / ${targetAmount}`);
      }
    });

    Object.keys(sendingAmount.erc721).forEach(addr => {
      let sendingNFTs: Field[] = sendingAmount.erc721[addr].sort((a, b) => (a.greaterThan(b) ? 1 : -1));
      let spendingNFTNotes: UTXO[] = this.spendables.filter(utxo => {
        return utxo.token.toHex() === addr && sendingNFTs.find(nft => nft.equal(utxo.nft)) !== undefined;
      });
      if (sendingNFTs.length == spendingNFTNotes.length) throw Error('Not enough NFTs');
      spendingNFTNotes.sort((a, b) => (a.nft.greaterThan(b.nft) ? 1 : -1));
      for (let i = 0; i < sendingNFTs.length; i++) {
        if (!sendingNFTs[i].equal(spendingNFTNotes[i].nft)) throw Error('Failed to find the exact NFT');
      }
      for (let utxo of spendingNFTNotes) {
        spendings.push(...spendables.splice(spendables.indexOf(utxo), 1));
      }
    });

    let requiredETH = sendingAmount.eth.add(this.fee);
    spendables.sort((a, b) => (a.eth.greaterThan(b.eth) ? -1 : 1));
    while (Asset.from(spendings).eth.gte(requiredETH)) {
      if (spendables.length === 0) throw Error('Not enough Ether');
      spendings.push(spendables.pop());
    }

    let changes: UTXO[] = [];
    let spendingAmount = Asset.from(spendings);
    Object.keys(spendingAmount.erc20).forEach(addr => {
      let change = spendingAmount.erc20[addr].sub(sendingAmount.erc20[addr]);
      if (!change.isZero()) {
        changes.push(UTXO.newERC20Note(0, Field.from(addr), change, this.changeTo));
      }
    });
    let extraNFTs: { [addr: string]: Field[] } = {};
    Object.keys(spendingAmount.erc721).forEach(addr => {
      extraNFTs[addr] = spendingAmount.erc721[addr].filter(nft => {
        if (sendingAmount[addr] === undefined) return true;
        else {
          if (sendingAmount[addr].find(nft) === undefined) return true;
        }
        return false;
      });
    });
    Object.keys(extraNFTs).forEach(addr => {
      extraNFTs[addr].forEach(nft => {
        changes.push(UTXO.newNFTNote(0, Field.from(addr), nft, this.changeTo));
      });
    });

    let changeETH = spendingAmount.eth.sub(sendingAmount.eth).sub(this.fee);
    if (!changeETH.isZero()) {
      changes.push(UTXO.newEtherNote(changeETH, this.changeTo));
    }

    let inflow = [...spendings];
    let outflow = [...this.sendings, ...changes];
    return {
      inflow,
      outflow,
      swap: this.swap,
      fee: this.fee
    };
  }
}

export class ZkWizard {
  circuits: { [key: string]: snarkjs.Circuit };
  vks: { [key: string]: {} };
  utxoGrove: UTXOGrove;
  privKey: string;
  pubKey: BabyJubjub.Point;

  constructor(utxoGrove: UTXOGrove, privKey: string) {
    this.utxoGrove = utxoGrove;
    this.privKey = privKey;
    this.circuits = {};
    this.vks = {};
    this.pubKey = BabyJubjub.Point.fromPrivKey(privKey);
  }

  support(n_i: number, n_o: number, circuitDef: {}, vkProof: {}) {
    this.circuits[this.circuitKey(n_i, n_o)] = new snarkjs.Circuit(circuitDef);
    this.vks[this.circuitKey(n_i, n_o)] = vkProof;
  }

  private circuitKey(n_i: number, n_o: number): string {
    return `${n_i}-${n_o}`;
  }

  async shield(tx: Transaction, toMemo?: UTXO): Promise<ZkTransaction> {
    return new Promise<ZkTransaction>((resolve, reject) => {
      let merkleProof: { [hash: string]: MerkleProof } = {};
      let eddsa: { [hash: string]: EdDSA } = {};
      let _this = this;

      function isDataPrepared(): boolean {
        return Object.keys(merkleProof).length === tx.inflow.length && Object.keys(eddsa).length === tx.inflow.length;
      }

      function genSNARK() {
        if (!isDataPrepared()) return;
        let circuit = _this.circuits[_this.circuitKey(tx.inflow.length, tx.outflow.length)];
        let vkProof = _this.vks[_this.circuitKey(tx.inflow.length, tx.outflow.length)];
        if (circuit === undefined || vkProof === undefined) {
          reject(`Does not support transactions for ${tx.inflow.length} inputs and ${tx.outflow.length} outputs`);
        }
        let input = {};
        // inflow data
        tx.inflow.forEach((utxo, i) => {
          // private signals
          input[`spending_note[0][${i}]`] = utxo.eth;
          input[`spending_note[1][${i}]`] = utxo.pubKey.x;
          input[`spending_note[2][${i}]`] = utxo.pubKey.y;
          input[`spending_note[3][${i}]`] = utxo.salt;
          input[`spending_note[4][${i}]`] = utxo.token;
          input[`spending_note[5][${i}]`] = utxo.amount;
          input[`spending_note[6][${i}]`] = utxo.nft;
          input[`signatures[0][${i}]`] = eddsa[i].R8.x;
          input[`signatures[1][${i}]`] = eddsa[i].R8.y;
          input[`signatures[2][${i}]`] = eddsa[i].S;
          input[`note_index[${i}]`] = merkleProof[i].index;
          for (let j = 0; j < _this.utxoGrove.depth; j++) {
            input[`siblings[${j}][${i}]`] = merkleProof[i].siblings[j];
          }
          // public signals
          input[`inclusion_references[${i}]`] = merkleProof[i].root;
          input[`nullifiers[${i}]`] = utxo.nullifier();
        });
        // outflow data
        tx.outflow.forEach((utxo, i) => {
          // private signals
          input[`new_note[0][${i}]`] = utxo.eth;
          input[`new_note[1][${i}]`] = utxo.pubKey.x;
          input[`new_note[2][${i}]`] = utxo.pubKey.y;
          input[`new_note[3][${i}]`] = utxo.salt;
          input[`new_note[4][${i}]`] = utxo.token;
          input[`new_note[5][${i}]`] = utxo.amount;
          input[`new_note[6][${i}]`] = utxo.nft;
          // public signals
          input[`new_note_hash[${i}]`] = utxo.hash();
          input[`typeof_new_note[${i}]`] = utxo.outflowType();
          input[`public_data[0][${i}]`] = utxo.publicData ? utxo.publicData.to : 0;
          input[`public_data[1][${i}]`] = utxo.publicData ? utxo.eth : 0;
          input[`public_data[2][${i}]`] = utxo.publicData ? utxo.token : 0;
          input[`public_data[3][${i}]`] = utxo.publicData ? utxo.amount : 0;
          input[`public_data[4][${i}]`] = utxo.publicData ? utxo.nft : 0;
          input[`public_data[5][${i}]`] = utxo.publicData ? utxo.publicData.fee : 0;
        });
        input[`swap`] = tx.swap ? tx.swap : 0;
        input[`fee`] = tx.fee;
        Object.keys(input).forEach(key => {
          input[key] = input[key].toString();
        });
        let witness = circuit.calculateWitness(input);
        let startTime = Date.now();
        let { proof } = snarkjs.groth.genProof(snarkjs.unstringifyBigInts(vkProof), witness);
        console.log(`proof generated in ${Date.now() - startTime} ms`);
        //TODO handle genProof exception
        let zkTx: ZkTransaction = new ZkTransaction(
          tx.inflow.map((utxo, index) => {
            return { nullifier: utxo.nullifier(), root: merkleProof[index].root };
          }),
          tx.outflow.map(utxo => utxo.toOutflow()),
          tx.fee,
          {
            pi_a: proof.pi_a.map(val => Field.from(val)),
            pi_b: proof.pi_b.map(arr => arr.map(val => Field.from(val))),
            pi_c: proof.pi_c.map(val => Field.from(val))
          },
          tx.swap,
          toMemo ? toMemo.encrypt() : undefined
        );
        resolve(zkTx);
      }

      function addMerkleProof(index: number, proof: MerkleProof) {
        merkleProof[index] = proof;
        genSNARK();
      }
      tx.inflow.forEach((utxo, index) => {
        eddsa[index] = sign(utxo.hash(), _this.privKey);
        _this.utxoGrove
          .merkleProof(utxo.hash())
          .then(proof => addMerkleProof(index, proof))
          .catch(reject);
      });
    });
  }
}
