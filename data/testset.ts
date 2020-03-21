// import { ec as EC, eddsa as EdDSA } from 'elliptic';
import { toHex, randomHex } from 'web3-utils';
import semaphore from 'semaphore-merkle-tree';
import { Field } from '../src/field';
import { UTXOGrove } from '../src/tree';
import { UTXO } from '../src/utxo';
import { ZkTransaction, TxBuilder, ZkWizard, Transaction } from '../src/transaction';
import { BabyJubjub } from '../src/jubjub';
import { TokenAddress } from '../src/tokens';
import fs from 'fs';

const alicePrivKey: string = "I am Alice's private key";
const alicePubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(alicePrivKey);
const bobPrivKey: string = "I am Bob's private key";
const bobPubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(bobPrivKey);

const utxo1_in_1: UTXO = UTXO.newEtherNote(3333, alicePubKey);
const utxo1_out_1: UTXO = UTXO.newEtherNote(2221, bobPubKey);
const utxo1_out_2: UTXO = UTXO.newEtherNote(1111, alicePubKey);

const utxo2_1_in_1: UTXO = UTXO.newERC20Note(22222333333, TokenAddress.DAI, 8888, alicePubKey);
const utxo2_1_out_1: UTXO = UTXO.newERC20Note(22222333332, TokenAddress.DAI, 5555, alicePubKey);
const utxo2_1_out_2: UTXO = UTXO.newERC20Note(0, TokenAddress.DAI, 3333, bobPubKey);

const KITTY_1 = '0x0078917891789178917891789178917891789178917891789178917891789178';
const KITTY_2 = '0x0022222222222222222222222222222222222222222222222222222222222222';

/** Ganache pre-defined addresses */
const ADDR1 = '0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1';
const ADDR2 = '0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0';

const utxo2_2_in_1: UTXO = UTXO.newNFTNote(7777777777, TokenAddress.CRYPTO_KITTIES, KITTY_1, bobPubKey);
const utxo2_2_out_1: UTXO = UTXO.newEtherNote(7777777776, bobPubKey);
const utxo2_2_out_2: UTXO = UTXO.newNFTNote(0, TokenAddress.CRYPTO_KITTIES, KITTY_1, alicePubKey);

const utxo3_in_1: UTXO = UTXO.newEtherNote(111111111111111, alicePubKey);
const utxo3_in_2: UTXO = UTXO.newEtherNote(222222222222222, alicePubKey);
const utxo3_in_3: UTXO = UTXO.newEtherNote(333333333333333, alicePubKey);
const utxo3_out_1: UTXO = UTXO.newEtherNote(666666666666664, alicePubKey);
utxo3_out_1.withdrawTo(Field.from(ADDR1), Field.from(1));

const utxo4_in_1: UTXO = UTXO.newEtherNote(8888888888888, alicePubKey);
const utxo4_in_2: UTXO = UTXO.newERC20Note(0, TokenAddress.DAI, 5555, alicePubKey);
const utxo4_in_3: UTXO = UTXO.newNFTNote(0, TokenAddress.CRYPTO_KITTIES, KITTY_2, alicePubKey);
const utxo4_out_1: UTXO = UTXO.newEtherNote(8888888888884, alicePubKey); // fee for tx & fee for withdrawal for each utxos
const utxo4_out_2: UTXO = UTXO.newERC20Note(0, TokenAddress.DAI, 5555, alicePubKey);
const utxo4_out_3: UTXO = UTXO.newNFTNote(0, TokenAddress.CRYPTO_KITTIES, KITTY_2, alicePubKey);

utxo4_out_1.migrateTo(Field.from(ADDR2), Field.from(1));
utxo4_out_2.migrateTo(Field.from(ADDR2), Field.from(1));
utxo4_out_3.migrateTo(Field.from(ADDR2), Field.from(1));

const tx_1: Transaction = {
  inflow: [utxo1_in_1],
  outflow: [utxo1_out_1, utxo1_out_2],
  fee: Field.from(1)
};

const tx_2_1: Transaction = {
  inflow: [utxo2_1_in_1],
  outflow: [utxo2_1_out_1, utxo2_1_out_2],
  swap: utxo2_2_out_2.hash(),
  fee: Field.from(1)
};

const tx_2_2: Transaction = {
  inflow: [utxo2_2_in_1],
  outflow: [utxo2_2_out_1, utxo2_2_out_2],
  swap: utxo2_1_out_2.hash(),
  fee: Field.from(1)
};

const tx_3: Transaction = {
  inflow: [utxo3_in_1, utxo3_in_2, utxo3_in_3],
  outflow: [utxo3_out_1],
  fee: Field.from(1)
};

const tx_4: Transaction = {
  inflow: [utxo4_in_1, utxo4_in_2, utxo4_in_3],
  outflow: [utxo4_out_1, utxo4_out_2, utxo4_out_3],
  fee: Field.from(1)
};

let zk_tx_1: ZkTransaction;
let zk_tx_2_1: ZkTransaction;
let zk_tx_2_2: ZkTransaction;
let zk_tx_3: ZkTransaction;
let zk_tx_4: ZkTransaction;

export const keys = {
  alicePrivKey,
  alicePubKey,
  bobPrivKey,
  bobPubKey
};

export const utxos = {
  utxo1_in_1,
  utxo1_out_1,
  utxo1_out_2,
  utxo2_1_in_1,
  utxo2_1_out_1,
  utxo2_2_in_1,
  utxo2_2_out_1,
  utxo2_2_out_2,
  utxo3_in_1,
  utxo3_in_2,
  utxo3_in_3,
  utxo3_out_1,
  utxo4_in_1,
  utxo4_in_2,
  utxo4_in_3,
  utxo4_out_1,
  utxo4_out_2,
  utxo4_out_3
};

export const txs = {
  tx_1,
  tx_2_1,
  tx_2_2,
  tx_3,
  tx_4
};

export interface TestSet {
  utxoGrove: UTXOGrove;
  zkTxs: ZkTransaction[];
}

export async function genTestSet(grovePath: string, ...txs: string[]): Promise<TestSet> {
  let utxoGrove = new UTXOGrove();
  let genesisTree = UTXOGrove.getOrCreateNewTree('build/1.tree');
  utxoGrove.addTree(genesisTree);
  await utxoGrove.appendUTXO(0, utxo1_in_1.hash());
  await utxoGrove.appendUTXO(1, utxo2_1_in_1.hash());
  await utxoGrove.appendUTXO(2, utxo2_2_in_1.hash());
  await utxoGrove.appendUTXO(3, utxo3_in_1.hash());
  await utxoGrove.appendUTXO(4, utxo3_in_2.hash());
  await utxoGrove.appendUTXO(5, utxo3_in_3.hash());
  await utxoGrove.appendUTXO(6, utxo4_in_1.hash());
  await utxoGrove.appendUTXO(7, utxo4_in_2.hash());
  await utxoGrove.appendUTXO(8, utxo4_in_3.hash());

  let circuit_1_2 = JSON.parse(fs.readFileSync('build/circuits/zk_transaction_1_2.json', 'utf8'));
  let circuit_3_1 = JSON.parse(fs.readFileSync('build/circuits/zk_transaction_3_1.json', 'utf8'));
  let circuit_3_3 = JSON.parse(fs.readFileSync('build/circuits/zk_transaction_3_3.json', 'utf8'));
  /** You should run test setup. Use ./script/test_setup.sh */
  let circuit_1_2_pk = JSON.parse(fs.readFileSync('build/pks/zk_transaction_1_2.pk.json', 'utf8'));
  let circuit_3_1_pk = JSON.parse(fs.readFileSync('build/pks/zk_transaction_3_1.pk.json', 'utf8'));
  let circuit_3_3_pk = JSON.parse(fs.readFileSync('build/pks/zk_transaction_3_3.pk.json', 'utf8'));
  const aliceZkWizard: ZkWizard = new ZkWizard(utxoGrove, alicePrivKey);
  const bobZkWizard: ZkWizard = new ZkWizard(utxoGrove, bobPrivKey);

  aliceZkWizard.support(1, 2, circuit_1_2, circuit_1_2_pk);
  aliceZkWizard.support(3, 1, circuit_3_1, circuit_3_1_pk);
  aliceZkWizard.support(3, 3, circuit_3_3, circuit_3_3_pk);
  bobZkWizard.support(1, 2, circuit_1_2, circuit_1_2_pk);

  console.log('Starts to zk proofs. It will take some time.');
  zk_tx_1 = await aliceZkWizard.shield(tx_1);
  zk_tx_2_1 = await aliceZkWizard.shield(tx_2_1);
  zk_tx_2_2 = await bobZkWizard.shield(tx_2_2);
  zk_tx_3 = await aliceZkWizard.shield(tx_3);
  zk_tx_4 = await aliceZkWizard.shield(tx_4);
  if (!fs.existsSync('build/txs')) {
    fs.mkdirSync('build/txs');
  }

  fs.writeFileSync('build/txs/zk_tx_1.tx', zk_tx_1.encode());
  fs.writeFileSync('build/txs/zk_tx_2_1.tx', zk_tx_2_1.encode());
  fs.writeFileSync('build/txs/zk_tx_2_2.tx', zk_tx_2_2.encode());
  fs.writeFileSync('build/txs/zk_tx_3.tx', zk_tx_3.encode());
  fs.writeFileSync('build/txs/zk_tx_4.tx', zk_tx_4.encode());
  return {
    utxoGrove,
    zkTxs: [zk_tx_1, zk_tx_2_1, zk_tx_2_2, zk_tx_3, zk_tx_4]
  };
}

export async function loadTestSet(grovePath: string, ...txs: string[]): Promise<TestSet> {
  if (fs.existsSync(`${grovePath}`) && txs.reduce((acc, path) => (fs.existsSync(path) ? acc + 1 : acc), 0) === txs.length) {
    let utxoGrove = new UTXOGrove();
    let genesisTree = UTXOGrove.getOrCreateNewTree(grovePath);
    utxoGrove.addTree(genesisTree);
    return {
      utxoGrove,
      zkTxs: txs.map(path => ZkTransaction.decode(fs.readFileSync(path)))
    };
  } else {
    return await genTestSet(grovePath, ...txs);
  }
}

// export const tx_1: ZkTransaction = {
//   inflow: [{ nullifier: utxo1_in_1.nullifier(), root: prevUTXORoot1 }],
//   outflow: [utxo1_out_1.toOutflow(), utxo1_out_2.toOutflow()],
//   fee: Field.from(1),
//   proof: { pi_a: [], pi_b: [[]], pi_c: [] }
// };

// export const tx_2_1: ZkTransaction = {
//   inflow: [{ nullifier: utxo2_1_in_1.nullifier(), root: prevUTXORoot1 }],
//   outflow: [utxo2_1_out_1.toOutflow(), utxo2_1_out_2.toOutflow()],
//   swap: utxo2_2_out_2.hash(),
//   fee: Field.from(1),
//   proof: { pi_a: [], pi_b: [[]], pi_c: [] }
// };

// export const tx_2_2: ZkTransaction = {
//   inflow: [{ nullifier: utxo2_2_in_1.nullifier(), root: prevUTXORoot1 }],
//   outflow: [utxo2_2_out_1.toOutflow(), utxo2_2_out_2.toOutflow()],
//   swap: utxo2_1_out_2.hash(),
//   fee: Field.from(1),
//   proof: { pi_a: [], pi_b: [[]], pi_c: [] }
// };
