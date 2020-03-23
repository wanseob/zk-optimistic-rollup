import { Field } from '../../src/field';
import { Grove } from '../../src/tree';
import { UTXO } from '../../src/utxo';
import { ZkTransaction } from '../../src/zk_transaction';
import { BabyJubjub } from '../../src/jubjub';
import { TokenAddress } from '../../src/tokens';
import { Transaction } from '../../src/transaction';
import { ZkWizard } from '../../src/zk_wizard';
import fs from 'fs-extra';

const alicePrivKey: string = "I am Alice's private key";
const alicePubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(alicePrivKey);
const bobPrivKey: string = "I am Bob's private key";
const bobPubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(bobPrivKey);

const utxo1_in_1: UTXO = UTXO.newEtherNote({ eth: 3333, pubKey: alicePubKey, salt: 11 });
const utxo1_out_1: UTXO = UTXO.newEtherNote({ eth: 2221, pubKey: bobPubKey, salt: 12 });
const utxo1_out_2: UTXO = UTXO.newEtherNote({ eth: 1111, pubKey: alicePubKey, salt: 13 });

const utxo2_1_in_1: UTXO = UTXO.newERC20Note({ eth: 22222333333, tokenAddr: TokenAddress.DAI, erc20Amount: 8888, pubKey: alicePubKey, salt: 14 });
const utxo2_1_out_1: UTXO = UTXO.newERC20Note({ eth: 22222333332, tokenAddr: TokenAddress.DAI, erc20Amount: 5555, pubKey: alicePubKey, salt: 15 });
const utxo2_1_out_2: UTXO = UTXO.newERC20Note({ eth: 0, tokenAddr: TokenAddress.DAI, erc20Amount: 3333, pubKey: bobPubKey, salt: 16 });

const KITTY_1 = '0x0078917891789178917891789178917891789178917891789178917891789178';
const KITTY_2 = '0x0022222222222222222222222222222222222222222222222222222222222222';

/** Ganache pre-defined addresses */
const USER_A = '0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1';
const CONTRACT_B = '0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0';

const utxo2_2_in_1: UTXO = UTXO.newNFTNote({ eth: 7777777777, tokenAddr: TokenAddress.CRYPTO_KITTIES, nft: KITTY_1, pubKey: bobPubKey, salt: 17 });
const utxo2_2_out_1: UTXO = UTXO.newEtherNote({ eth: 7777777776, pubKey: bobPubKey, salt: 18 });
const utxo2_2_out_2: UTXO = UTXO.newNFTNote({ eth: 0, tokenAddr: TokenAddress.CRYPTO_KITTIES, nft: KITTY_1, pubKey: alicePubKey, salt: 19 });

const utxo3_in_1: UTXO = UTXO.newEtherNote({ eth: 111111111111111, pubKey: alicePubKey, salt: 21 });
const utxo3_in_2: UTXO = UTXO.newEtherNote({ eth: 222222222222222, pubKey: alicePubKey, salt: 22 });
const utxo3_in_3: UTXO = UTXO.newEtherNote({ eth: 333333333333333, pubKey: alicePubKey, salt: 23 });
const utxo3_out_1: UTXO = UTXO.newEtherNote({ eth: 666666666666664, pubKey: alicePubKey, salt: 24 });
utxo3_out_1.markAsWithdrawal({ to: Field.from(USER_A), fee: Field.from(1) });

const utxo4_in_1: UTXO = UTXO.newEtherNote({ eth: 8888888888888, pubKey: alicePubKey, salt: 25 });
const utxo4_in_2: UTXO = UTXO.newERC20Note({ eth: 0, tokenAddr: TokenAddress.DAI, erc20Amount: 5555, pubKey: alicePubKey, salt: 26 });
const utxo4_in_3: UTXO = UTXO.newNFTNote({ eth: 0, tokenAddr: TokenAddress.CRYPTO_KITTIES, nft: KITTY_2, pubKey: alicePubKey, salt: 27 });
const utxo4_out_1: UTXO = UTXO.newEtherNote({ eth: 8888888888884, pubKey: alicePubKey, salt: 28 }); // fee for tx & fee for withdrawal for each utxos
const utxo4_out_2: UTXO = UTXO.newERC20Note({ eth: 0, tokenAddr: TokenAddress.DAI, erc20Amount: 5555, pubKey: alicePubKey, salt: 29 });
const utxo4_out_3: UTXO = UTXO.newNFTNote({ eth: 0, tokenAddr: TokenAddress.CRYPTO_KITTIES, nft: KITTY_2, pubKey: alicePubKey, salt: 30 });
utxo4_out_1.markAsMigration({ to: Field.from(CONTRACT_B), fee: Field.from(1) });
utxo4_out_2.markAsMigration({ to: Field.from(CONTRACT_B), fee: Field.from(1) });
utxo4_out_3.markAsMigration({ to: Field.from(CONTRACT_B), fee: Field.from(1) });

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

export const keys = {
  alicePrivKey,
  alicePubKey,
  bobPrivKey,
  bobPubKey
};

export const address = {
  USER_A,
  CONTRACT_B,
  CRYPTO_KITTIES: TokenAddress.CRYPTO_KITTIES,
  DAI: TokenAddress.DAI
};

export const nfts = {
  KITTY_1,
  KITTY_2
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
  utxoGrove: Grove;
  zkTxs: ZkTransaction[];
  closeDB: () => Promise<void>;
}

export async function loadGrove(): Promise<{ grove: Grove; close: () => Promise<void> }> {
  let treePath = 'build/tree1';
  // reset data
  fs.removeSync(treePath);
  let grove = new Grove('zkopru', treePath, 31);
  await grove.init();
  let latestTree = grove.latestUTXOTree();
  let size = latestTree ? await latestTree.size() : BigInt(0);
  if (size == BigInt(0)) {
    await grove.appendUTXO(utxo1_in_1.hash().toHex());
    await grove.appendUTXO(utxo2_1_in_1.hash().toHex());
    await grove.appendUTXO(utxo2_2_in_1.hash().toHex());
    await grove.appendUTXO(utxo3_in_1.hash().toHex());
    await grove.appendUTXO(utxo3_in_2.hash().toHex());
    await grove.appendUTXO(utxo3_in_3.hash().toHex());
    await grove.appendUTXO(utxo4_in_1.hash().toHex());
    await grove.appendUTXO(utxo4_in_2.hash().toHex());
    await grove.appendUTXO(utxo4_in_3.hash().toHex());
  }
  let close = async () => {
    await grove.close();
  };
  return { grove, close };
}

export function loadCircuits(): {
  circuit_1_2: any;
  circuit_1_2_pk: any;
  circuit_3_1: any;
  circuit_3_1_pk: any;
  circuit_3_3: any;
  circuit_3_3_pk: any;
} {
  let circuit_1_2 = JSON.parse(fs.readFileSync('build/circuits.test/zk_transaction_1_2.test.json', 'utf8'));
  let circuit_3_1 = JSON.parse(fs.readFileSync('build/circuits.test/zk_transaction_3_1.test.json', 'utf8'));
  let circuit_3_3 = JSON.parse(fs.readFileSync('build/circuits.test/zk_transaction_3_3.test.json', 'utf8'));
  let circuit_1_2_pk = JSON.parse(fs.readFileSync('build/pks.test/zk_transaction_1_2.test.pk.json', 'utf8'));
  let circuit_3_1_pk = JSON.parse(fs.readFileSync('build/pks.test/zk_transaction_3_1.test.pk.json', 'utf8'));
  let circuit_3_3_pk = JSON.parse(fs.readFileSync('build/pks.test/zk_transaction_3_3.test.pk.json', 'utf8'));
  return {
    circuit_1_2,
    circuit_1_2_pk,
    circuit_3_1,
    circuit_3_1_pk,
    circuit_3_3,
    circuit_3_3_pk
  };
}

export function loadPrebuiltZkTxs(): ZkTransaction[] {
  let prebuiltTxs = ['data/txs/zk_tx_1.tx', 'data/txs/zk_tx_2_1.tx', 'data/txs/zk_tx_2_2.tx', 'data/txs/zk_tx_3.tx', 'data/txs/zk_tx_4.tx'];
  return prebuiltTxs.map(path => ZkTransaction.decode(fs.readFileSync(path)));
}

export async function buildAndSaveZkTxs(): Promise<void> {
  let { grove, close } = await loadGrove();
  let aliceZkWizard = new ZkWizard({
    grove,
    privKey: alicePrivKey
  });
  let bobZkWizard = new ZkWizard({
    grove,
    privKey: keys.bobPrivKey
  });
  let { circuit_1_2, circuit_1_2_pk, circuit_3_1, circuit_3_1_pk, circuit_3_3, circuit_3_3_pk } = loadCircuits();
  aliceZkWizard.addCircuit({ n_i: 1, n_o: 2, circuitDef: circuit_1_2, provingKey: circuit_1_2_pk });
  aliceZkWizard.addCircuit({ n_i: 3, n_o: 1, circuitDef: circuit_3_1, provingKey: circuit_3_1_pk });
  aliceZkWizard.addCircuit({ n_i: 3, n_o: 3, circuitDef: circuit_3_3, provingKey: circuit_3_3_pk });
  bobZkWizard.addCircuit({ n_i: 1, n_o: 2, circuitDef: circuit_1_2, provingKey: circuit_1_2_pk });
  let zk_tx_1 = await aliceZkWizard.shield({ tx: tx_1 });
  let zk_tx_2_1 = await aliceZkWizard.shield({ tx: tx_2_1 });
  let zk_tx_2_2 = await bobZkWizard.shield({ tx: tx_2_2 });
  let zk_tx_3 = await aliceZkWizard.shield({ tx: tx_3 });
  let zk_tx_4 = await aliceZkWizard.shield({ tx: tx_4 });
  fs.writeFileSync('data/txs/zk_tx_1.tx', zk_tx_1.encode());
  fs.writeFileSync('data/txs/zk_tx_2_1.tx', zk_tx_2_1.encode());
  fs.writeFileSync('data/txs/zk_tx_2_2.tx', zk_tx_2_2.encode());
  fs.writeFileSync('data/txs/zk_tx_3.tx', zk_tx_3.encode());
  fs.writeFileSync('data/txs/zk_tx_4.tx', zk_tx_4.encode());
  await close();
  return;
}
