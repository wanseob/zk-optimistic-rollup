import { soliditySha3, Hex, toBN } from 'web3-utils';

declare module ZkOpRollUp {}
export interface MerkleProof {
  root: Hex;
  leaf: Hex;
  val: Hex;
  siblings: Hex[];
}

export interface Hasher {
  hash(val: Hex): Hex;
  combinedHash(left: Hex, right: Hex): Hex;
}

export interface MerkleTree {
  depth: number;
  hasher: Hasher;
  root(): Promise<Hex>;
  updateLeaf(leaf: Hex, val: Hex): Promise<MerkleProof>;
  merkleProof(leaf: Hex): Promise<MerkleProof>;
  verityProof(proof: MerkleProof): boolean;
}

export interface TxPool {}

export interface ZkTxBuilder {}
