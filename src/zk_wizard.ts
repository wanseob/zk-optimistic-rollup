import { Field } from './field';
import { BabyJubjub } from './jubjub';
import { Grove, MerkleProof } from './tree';
import { EdDSA, sign } from './eddsa';
import * as snarkjs from 'snarkjs';
import { Transaction } from './transaction';
import { ZkTransaction } from './zk_transaction';

export class ZkWizard {
  circuits: { [key: string]: snarkjs.Circuit };
  provingKeys: { [key: string]: {} };
  grove: Grove;
  privKey: string;
  pubKey: BabyJubjub.Point;

  constructor({ grove, privKey }: { grove: Grove; privKey: string }) {
    this.grove = grove;
    this.privKey = privKey;
    this.circuits = {};
    this.provingKeys = {};
    this.pubKey = BabyJubjub.Point.fromPrivKey(privKey);
  }

  addCircuit({ n_i, n_o, circuitDef, provingKey }: { n_i: number; n_o: number; circuitDef: {}; provingKey: {} }) {
    this.circuits[this.circuitKey({ n_i, n_o })] = new snarkjs.Circuit(circuitDef);
    this.provingKeys[this.circuitKey({ n_i, n_o })] = provingKey;
  }

  private circuitKey({ n_i, n_o }: { n_i: number; n_o: number }): string {
    return `${n_i}-${n_o}`;
  }

  /**
   * @param toMemo n-th outflow will be encrypted
   */
  async shield({ tx, toMemo }: { tx: Transaction; toMemo?: number }): Promise<ZkTransaction> {
    return new Promise<ZkTransaction>((resolve, reject) => {
      let merkleProof: { [hash: string]: MerkleProof } = {};
      let eddsa: { [hash: string]: EdDSA } = {};
      let _this = this;

      function isDataPrepared(): boolean {
        return Object.keys(merkleProof).length === tx.inflow.length && Object.keys(eddsa).length === tx.inflow.length;
      }

      function genSNARK() {
        if (!isDataPrepared()) return;
        let circuit = _this.circuits[_this.circuitKey({ n_i: tx.inflow.length, n_o: tx.outflow.length })];
        let provingKey = _this.provingKeys[_this.circuitKey({ n_i: tx.inflow.length, n_o: tx.outflow.length })];
        if (circuit === undefined || provingKey === undefined) {
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
          input[`spending_note[4][${i}]`] = utxo.tokenAddr;
          input[`spending_note[5][${i}]`] = utxo.erc20Amount;
          input[`spending_note[6][${i}]`] = utxo.nft;
          input[`signatures[0][${i}]`] = eddsa[i].R8.x;
          input[`signatures[1][${i}]`] = eddsa[i].R8.y;
          input[`signatures[2][${i}]`] = eddsa[i].S;
          input[`note_index[${i}]`] = merkleProof[i].index;
          for (let j = 0; j < _this.grove.depth; j++) {
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
          input[`new_note[4][${i}]`] = utxo.tokenAddr;
          input[`new_note[5][${i}]`] = utxo.erc20Amount;
          input[`new_note[6][${i}]`] = utxo.nft;
          // public signals
          input[`new_note_hash[${i}]`] = utxo.hash();
          input[`typeof_new_note[${i}]`] = utxo.outflowType();
          input[`public_data[0][${i}]`] = utxo.publicData ? utxo.publicData.to : 0;
          input[`public_data[1][${i}]`] = utxo.publicData ? utxo.eth : 0;
          input[`public_data[2][${i}]`] = utxo.publicData ? utxo.tokenAddr : 0;
          input[`public_data[3][${i}]`] = utxo.publicData ? utxo.erc20Amount : 0;
          input[`public_data[4][${i}]`] = utxo.publicData ? utxo.nft : 0;
          input[`public_data[5][${i}]`] = utxo.publicData ? utxo.publicData.fee : 0;
        });
        input[`swap`] = tx.swap ? tx.swap : 0;
        input[`fee`] = tx.fee;
        Object.keys(input).forEach(key => {
          input[key] = input[key].toString();
        });
        let witness = circuit.calculateWitness(input);
        let { proof, publicSignals } = snarkjs.groth.genProof(snarkjs.unstringifyBigInts(provingKey), witness);
        //TODO handle genProof exception
        let zkTx: ZkTransaction = new ZkTransaction({
          inflow: tx.inflow.map((utxo, index) => {
            return {
              nullifier: utxo.nullifier(),
              root: merkleProof[index].root
            };
          }),
          outflow: tx.outflow.map(utxo => utxo.toOutflow()),
          fee: tx.fee,
          proof: {
            pi_a: proof.pi_a.map(val => Field.from(val)),
            pi_b: proof.pi_b.map(arr => arr.map(val => Field.from(val))),
            pi_c: proof.pi_c.map(val => Field.from(val))
          },
          swap: tx.swap,
          memo: toMemo ? tx.outflow[toMemo].encrypt() : undefined
        });
        resolve(zkTx);
      }

      function addMerkleProof({ index, proof }: { index: number; proof: MerkleProof }) {
        merkleProof[index] = proof;
        genSNARK();
      }
      tx.inflow.forEach((utxo, index) => {
        eddsa[index] = sign({ msg: utxo.hash(), privKey: _this.privKey });
        _this.grove
          .utxoMerkleProof(utxo.hash().toHex())
          .then(proof => addMerkleProof({ index, proof }))
          .catch(reject);
      });
    });
  }
}
