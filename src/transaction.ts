import RocksDB from 'level-rocksdb';
import BN from 'bn.js';
import { UTXO } from './utxo';
import { Field } from './field';

export interface ZkTransaction {
  inflow: Inflow[];
  outflow: Outflow[];
  swap?: Field;
  fee: Field;
  proof?: SNARK;
  memo?: Field;
}

export interface Inflow {
  nullifier: Field;
  root: Field;
}

export interface Outflow {
  note: Field;
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

export class UTXOManager {
  utxoDB: RocksDB;

  constructor(path: string) {
    this.utxoDB = RocksDB(path + '/utxo');
  }

  async addSpendable(utxo: UTXO): Promise<boolean> {
    return new Promise<boolean>(resolve => {
      // this.utxoDB.put(utxo.hash(), utxo.stringify(), err => {
      //   if (err) {
      //     // throw err;
      //     resolve(false);
      //   } else {
      //     resolve(true);
      //   }
      // });
    });
  }

  markAsPending(id: number) {
    // this.pending.push(this.spendable.pop(utxo));
  }

  spendableETH(): BN {
    let amount: BN = new BN(0);
    // for(let utxo of this.spendable) {
    // amount.add(toBN(utxo.eth))
    // }
    return amount;
  }

  tokens(): Object {
    let tokens = {};
    /**
    for(let utxo of this.spendable) {
      if(utxo.token && !toBN(utxo.token).isZero()) {
        let erc20 = toBN(utxo.amount);
        let nft = utxo.nft;
        let isERC20 = !erc20.isZero();
        if (isERC20) {
          let amount = tokens[utxo.token] ? erc20.add(tokens[utxo.token]) : erc20;
          tokens[utxo.token] = amount;
        } else {
          let nfts = tokens[utxo.token] ? tokens[utxo.token].push(nft) : [nft];
          tokens[utxo.token] = nfts;
        }
      }
    }
     */
    return tokens;
  }

  markAsSpent(nullifier: Field) {}

  sendETH(eth: BN): ZkTransaction {
    return;
  }

  sendERC20(token: Field, amount: BN): ZkTransaction {
    return;
  }

  sendNFT(token: Field, nft: Field): ZkTransaction {
    return;
  }

  mergeETH(): ZkTransaction {
    return;
  }

  mergeERC20(addr: Field): ZkTransaction {
    return;
  }
}
