import RocksDB from 'level-rocksdb';
import { hashers, tree, storage } from 'semaphore-merkle-tree';
import { Field } from './field';
import { Hex, soliditySha3, toBN } from 'web3-utils';

export interface MerkleProof {
  root: Field;
  index: Field;
  utxo: Field;
  siblings: Field[];
}

class RocksDBStorage {
  db: RocksDB;
  constructor(path: string) {
    this.db = RocksDB(path);
  }

  async open() {
    await this.db.open();
  }

  async get(key): Promise<string> {
    return await this.db.get(key.toString());
  }

  async get_or_element(key, element): Promise<string> {
    let res;
    try {
      res = await this.db.get(key.toString());
    } catch {
      res = element;
    }
    return res;
  }

  async put(key, value) {
    await this.db.put(key, value);
  }

  async del(key) {
    await this.db.del(key);
  }

  async put_batch(key_values) {
    await this.db.batch(
      key_values.map(item => {
        return { type: 'put', ...item };
      })
    );
  }

  async close() {
    await this.db.close();
  }
}

export class MerkleTree {
  tree: tree.MerkleTree;
  storage: RocksDBStorage;
  prefix: string;
  maxSize: bigint;

  constructor(prefix: string, storage: storage.IStorage, hasher: hashers.IHasher, depth: number, defaultValue: Hex) {
    this.prefix = prefix;
    this.storage = storage;
    this.tree = new tree.MerkleTree(prefix, storage, hasher, depth, defaultValue);
    this.maxSize = BigInt(1) << BigInt(depth);
  }

  async append(utxo: Hex) {
    let size = await this.size();
    if (size >= this.maxSize) {
      throw Error('Tree is fully filled.');
    }
    let index = size + BigInt(1);
    await this.tree.update(index.toString(), utxo);
    let root = await this.tree.root();
    await this.recordSize(root, index);
  }

  async size(): Promise<bigint> {
    let root = await this.tree.root();
    let size;
    try {
      size = await this.storage.get(this.sizeKey(root));
    } catch {
      size = 0;
    } finally {
      return BigInt(size);
    }
  }

  async rollBack(root: Hex) {
    this.tree.rollback_to_root(root);
  }

  async include(utxo: Hex): Promise<boolean> {
    let itemIndex = parseInt(await this.tree.element_index(utxo));
    return itemIndex !== -1;
  }

  async merkleProof(utxo: Hex): Promise<MerkleProof> {
    let itemIndex = parseInt(await this.tree.element_index(utxo));
    if (itemIndex === -1) return null;
    else {
      let path = await this.tree.path(itemIndex);
      return {
        root: Field.from(path.root),
        index: Field.from(itemIndex),
        utxo: Field.from(utxo),
        siblings: path.path_elements.map(sib => Field.from(sib))
      };
    }
  }

  private async recordSize(root: Hex, size: bigint): Promise<void> {
    this.storage.put(this.sizeKey(root), size);
  }

  private sizeKey(root: Hex): string {
    return `${this.prefix}-${root}-size`;
  }
}

export const keccakHasher = {
  hash: (_, left, right) => {
    return toBN(soliditySha3(left, right));
  }
};

export class Grove {
  utxoTrees: MerkleTree[];
  withdrawalTrees: MerkleTree[];
  nullifierTree: MerkleTree;
  depth: number;
  prefix: string;
  storage: RocksDBStorage;

  constructor(prefix: string, path: string, depth: number) {
    this.prefix = prefix;
    this.utxoTrees = [];
    this.withdrawalTrees = [];
    this.storage = new RocksDBStorage(path);
    this.depth = depth;
  }

  async init() {
    // Retrieve UTXO trees
    let numOfUTXOTrees: number;
    try {
      numOfUTXOTrees = parseInt(await this.storage.get(this.prefixForNumOfUtxoTrees()));
    } catch {
      numOfUTXOTrees = 0;
    } finally {
      for (let i = 0; i < numOfUTXOTrees; i++) {
        this.utxoTrees[i] = Grove.utxoTree(this.prefixForUtxoTree(i), this.depth, this.storage);
      }
    }
    // Retrieve Withdrawal trees
    let numOfWithdrawalTrees: number;
    try {
      numOfWithdrawalTrees = parseInt(await this.storage.get(this.prefixForNumOfWithdrawalTrees));
    } catch {
      numOfWithdrawalTrees = 0;
    } finally {
      for (let i = 0; i < numOfWithdrawalTrees; i++) {
        this.withdrawalTrees[i] = Grove.withdrawalTree(this.prefixForWithdrawalTree(i), this.depth, this.storage);
      }
    }
    // Retrieve the nullifier tree
    this.nullifierTree = Grove.nullifierTree(this.prefixForNullifierTree(), this.storage);
  }

  latestUTXOTree(): MerkleTree {
    return this.utxoTrees[this.utxoTrees.length - 1];
  }

  latestWithdrawalTree(): MerkleTree {
    return this.withdrawalTrees[this.withdrawalTrees.length - 1];
  }

  async appendUTXO(utxo: Hex): Promise<void> {
    let tree = this.latestUTXOTree();
    if (tree && (await tree.size()) < tree.maxSize) {
      await tree.append(utxo);
    } else {
      let newTreeIndex = this.utxoTrees.length;
      let newTree = Grove.utxoTree(this.prefixForUtxoTree(newTreeIndex), this.depth, this.storage);
      this.utxoTrees.push(newTree);
      await this.recordTrees();
      await newTree.append(utxo);
    }
  }

  async appendWithdrawal(withdrawal: Hex): Promise<void> {
    let tree = this.latestWithdrawalTree();
    if ((await tree.size()) < tree.maxSize) {
      await tree.append(withdrawal);
    } else {
      let newTreeIndex = this.withdrawalTrees.length;
      let newTree = Grove.withdrawalTree(this.prefixForWithdrawalTree(newTreeIndex), this.depth, this.storage);
      this.withdrawalTrees.push(newTree);
      await this.recordTrees();
      await newTree.append(withdrawal);
    }
  }

  async close() {
    await this.recordTrees();
    await this.storage.close();
  }

  async utxoMerkleProof(utxo: Hex): Promise<MerkleProof> {
    let index = -1;
    let tree: MerkleTree;
    let proof;
    for (let i = this.utxoTrees.length; i--; ) {
      tree = this.utxoTrees[i];
      proof = await tree.merkleProof(utxo);
      if (proof) break;
    }
    if (!proof) throw Error('Failed to find utxo');
    return proof;
  }

  async withdrawalMerkleProof(withdrawal: Hex): Promise<MerkleProof> {
    let index = -1;
    let tree: MerkleTree;
    let proof;
    for (let i = this.withdrawalTrees.length; i--; ) {
      tree = this.withdrawalTrees[i];
      proof = await tree.merkleProof(withdrawal);
      if (proof) break;
    }
    if (!proof) throw Error('Failed to find utxo');
    return proof;
  }

  private async recordTrees() {
    await this.storage.put_batch([
      {
        key: this.prefixForNumOfUtxoTrees(),
        value: this.utxoTrees.length
      },
      {
        key: this.prefixForNumOfWithdrawalTrees(),
        value: this.withdrawalTrees.length
      }
    ]);
  }

  private prefixForNumOfUtxoTrees(): string {
    return `${this.prefix}-utxo-num`;
  }

  private prefixForNumOfWithdrawalTrees(): string {
    return `${this.prefix}-withdrawal-num`;
  }

  private prefixForUtxoTree(groveIndex: number): string {
    return `${this.prefix}-utxo-${groveIndex}`;
  }

  private prefixForWithdrawalTree(groveIndex: number): string {
    return `${this.prefix}-withdrawal-${groveIndex}`;
  }

  private prefixForNullifierTree(): string {
    return `${this.prefix}-nullifier`;
  }

  static utxoTree(prefix: string, depth: number, storage: RocksDBStorage): tree.MerkleTree {
    let hasher = new hashers.PoseidonHasher();
    let defaultValue = '0';
    return new MerkleTree(prefix, storage, hasher, depth, defaultValue);
  }

  static withdrawalTree(prefix: string, depth: number, storage: RocksDBStorage): tree.MerkleTree {
    let hasher = keccakHasher;
    let defaultValue = '0';
    return new MerkleTree(prefix, storage, hasher, depth, defaultValue);
  }

  static nullifierTree(prefix: string, storage: RocksDBStorage): tree.MerkleTree {
    let hasher = keccakHasher;
    let defaultValue = '0';
    let depth = 255;
    return new MerkleTree(prefix, storage, hasher, depth, defaultValue);
  }
}
