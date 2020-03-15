import { Hex } from 'web3-utils';

export class ZkTransaction {
  inflow: Inflow[];
  outflow: Outflow[];
  swap?: Hex;
  fee: Hex;
  proof?: SNARK;
  memo?: Hex;
}

export interface Inflow {
  nullifier: Hex;
  root: Hex;
}

export interface Outflow {
  note: Hex;
  data?: PublicData;
}

export interface PublicData {
  to: Hex;
  eth: Hex;
  token: Hex;
  amount: Hex;
  nft: Hex;
  fee: Hex;
}

export interface SNARK {
  pi_a: Hex[];
  pi_b: Hex[][];
  pi_c: Hex[];
}
