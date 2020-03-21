import RocksDB from 'level-rocksdb';
import { storage, hashers, tree } from 'semaphore-merkle-tree';
import { Field } from './field';

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
}

export class UTXOGrove {
  trees: tree.MerkleTree[];
  depth: number;

  constructor() {
    this.trees = [];
  }

  latest(): tree.MerkleTree {
    return this.trees[this.trees.length - 1];
  }

  async merkleProof(utxoHash: Field): Promise<MerkleProof> {
    let item = utxoHash.toHex();
    let index = -1;
    let tree: tree.MerkleTree;
    for (let i = this.trees.length; i--; ) {
      tree = this.trees[i];
      index = parseInt(await tree.element_index(item));
      if (index !== -1) break;
      else continue;
    }
    if (index === -1) throw Error('Failed to find utxo');
    let path = await tree.path(index);
    // console.log(
    //   "merkleProof",
    //   path.path_elements.length,
    //   {
    //   root: Field.from(path.root),
    //   index: Field.from(index),
    //   utxo: utxoHash,
    //   siblings: path.path_elements.map(sib=>Field.from(sib))
    // }

    // )

    return {
      root: Field.from(path.root),
      index: Field.from(index),
      utxo: utxoHash,
      siblings: path.path_elements.map(sib => Field.from(sib))
    };
  }

  async appendUTXO(index: number, utxo: Field): Promise<void> {
    let tree = this.latest();
    // TODO create new tree
    await tree.update(index, utxo.toHex());
    return;
  }

  addTree(tree: tree.MerkleTree) {
    if (this.depth) {
      // Check the tree has same depth
      if (tree.n_levels !== this.depth) throw Error('The tree has different depth');
    } else {
      // Initialize the depth of the grove
      this.depth = tree.n_levels;
    }
    this.trees.push(tree);
  }

  addTrees(...trees: tree.MerkleTree[]) {
    trees.forEach(this.addTree);
  }

  static getOrCreateNewTree(path: string): tree.MerkleTree {
    let strg = new RocksDBStorage(path);
    let hasher = new hashers.PoseidonHasher();
    let prefix = 'zkopru';
    let defaultValue = '0';
    let depth = 31;
    return new tree.MerkleTree(prefix, strg, hasher, depth, defaultValue);
  }
}
