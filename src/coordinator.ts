import { Hex } from 'web3-utils';
import { ZkTransaction } from './transaction';

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
