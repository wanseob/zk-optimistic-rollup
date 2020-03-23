import { Hex } from 'web3-utils';
import { ZkTransaction } from './zk_transaction';
import { root } from './utils';
import * as snarkjs from 'snarkjs';

export interface Block {
  header: Header;
  body: Body;
}

export interface Header {
  proposer: Hex;
  parentBlock: Hex;
  metadata: Hex;
  fee: Hex;
  /** UTXO roll up  */
  prevUTXORoot: Hex;
  prevUTXOIndex: Hex;
  nextUTXORoot: Hex;
  nextUTXOIndex: Hex;
  /** Nullifier roll up  */
  prevNullifierRoot: Hex;
  nextNullifierRoot: Hex;
  prevWithdrawalRoot: Hex;
  prevWithdrawalIndex: Hex;
  /** Withdrawal roll up  */
  nextWithdrawalRoot: Hex;
  nextWithdrawalIndex: Hex;
  /** Transactions */
  txRoot: Hex;
  depositRoot: Hex;
  migrationRoot: Hex;
}

export interface Body {
  txs: ZkTransaction[];
  deposits: MassDeposit[];
  migrations: MassMigration[];
}

export interface MassDeposit {
  merged: Hex;
  fee: Hex;
}

export interface MassMigration {
  destination: Hex;
  totalETH: Hex;
  migratingLeaves: MassDeposit;
  erc20: ERC20Migration[];
  erc721: ERC721Migration[];
}

export interface ERC20Migration {
  addr: Hex;
  amount: Hex;
}

export interface ERC721Migration {
  addr: Hex;
  nfts: Hex[];
}

export interface AggregatedZkTx {
  zkTx: ZkTransaction;
  includedIn: Hex; // block hash
}

const PENDING = 'pending';

export class TxMemPool {
  blockTxMap: {
    [includedIn: string]: Hex[];
  };
  txs: {
    [txHash: string]: ZkTransaction;
  };
  verifyingKeys: { [key: string]: {} };

  constructor() {
    this.blockTxMap = {
      [PENDING]: []
    };
    this.txs = {};
    this.verifyingKeys = {};
  }

  addVerifier({ n_i, n_o, vk }: { n_i: number; n_o: number; vk: any }) {
    let key = `${n_i}-${n_o}`;
    this.verifyingKeys[key] = snarkjs.unstringifyBigInts(vk);
  }

  pendingNum(): number {
    return this.blockTxMap[PENDING].length;
  }

  addToTxPool(zkTx: ZkTransaction) {
    let txHash = zkTx.hash();
    if (!this.verifyTx(zkTx)) {
      throw Error('SNARK is invalid');
    }
    this.addToBlock({ blockHash: PENDING, txHash });
    this.txs[txHash] = zkTx;
  }

  pickPendingTxs(maxBytes: number): ZkTransaction[] {
    let available = maxBytes;
    this.sortPendingTxs();
    let candidates = this.blockTxMap[PENDING];
    let picked: ZkTransaction[] = [];
    while (available > 0 && candidates.length > 0) {
      let tx = this.txs[candidates.pop()];
      let size = tx.size();
      if (available >= size) {
        available -= size;
        picked.push(tx);
      }
    }
    let txHashes = picked.map(tx => tx.hash());
    let txRoot = root(txHashes);
    this.blockTxMap[txRoot] = txHashes;
    return picked;
  }

  updateTxsAsIncludedInBlock({ txRoot, blockHash }: { txRoot: string; blockHash: string }) {
    this.blockTxMap[blockHash] = this.blockTxMap[txRoot];
    delete this.blockTxMap[txRoot];
  }

  verifyTx(zkTx: ZkTransaction): boolean {
    let key = `${zkTx.inflow.length}-${zkTx.outflow.length}`;
    let isValid = snarkjs.groth.isValid(this.verifyingKeys[key], zkTx.circomProof(), zkTx.signals());
    return isValid;
  }

  revertTxs(txRoot: string) {
    this.blockTxMap[txRoot].forEach(hash => this.blockTxMap[PENDING].push(hash));
    this.sortPendingTxs();
  }

  private sortPendingTxs() {
    this.blockTxMap[PENDING].sort((a, b) => (this.txs[a].fee.greaterThan(this.txs[b].fee) ? 1 : -1));
  }

  private addToBlock({ blockHash, txHash }: { blockHash: string; txHash: Hex }) {
    let txHashes: Hex[] = this.blockTxMap[blockHash];
    // let txs: ZkTransaction[] = this.txs[blockHash];
    if (!txHashes) {
      txHashes = [];
      this.blockTxMap[blockHash] = txHashes;
    }
    let alreadyExist = txHashes.reduce((exist, val) => {
      if (exist) return true;
      else {
        return val === txHash;
      }
    }, false);
    if (!alreadyExist) {
      txHashes.push(txHash);
    } else {
      throw Error('Already exists');
    }
  }

  async blockReverted(blockHash: string) {
    try {
      // this.db.create
    } finally {
    }
  }
}

export class Coordinator {}
