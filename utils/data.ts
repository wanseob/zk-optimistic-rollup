// import { ec as EC, eddsa as EdDSA } from 'elliptic';
import { Hex, toHex, randomHex } from 'web3-utils';
import semaphore from '../node_modules/semaphore-merkle-tree/ts/index';
import { UTXO } from '../src/utxo';
import { ZkTransaction } from '../src/transaction';
import { BabyJubjub } from '../src/jubjub';

const storage = new semaphore.storage.MemStorage();
const hasher = new semaphore.hashers.PoseidonHasher();
const prefix = 'zkopru';
const defaultValue = '0';
const depth = 31;

const merkleTree = new semaphore.tree.MerkleTree(prefix, storage, hasher, depth, defaultValue);

const alicePrivKey: Hex = randomHex(31);
const alicePubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(alicePrivKey);
const bobPrivKey: Hex = randomHex(31);
const bobPubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(bobPrivKey);

const utxo1_in_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000000000000033333333333',
  salt: '0x94efd282e2450bab4c8b7c977cfd30e3',
  pubKey: alicePubKey
});

const utxo1_out_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000000000000022222222221',
  salt: '0xa3b5632e3223cd2ff9ff322a12328caf',
  pubKey: bobPubKey
});

const utxo1_out_2: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000000000000011111111111',
  salt: '0xdc2acd387901234112bc37651aafed21',
  pubKey: alicePubKey
});

const utxo2_in_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000000000000022222333333',
  salt: '0xccdeaf231890f23982cdb13973322ae6',
  token: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  amount: '0x0000000000000000000088888888888888888888888888888888888888888888',
  pubKey: alicePubKey
});

const utxo2_in_2: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000007777777777777777777',
  salt: '0xccdeaf231890f23982cdb13973322ae6',
  token: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  nft: '0x9178917891789178917891789178917891789178917891789178917891789178',
  pubKey: bobPubKey
});

const utxo2_out_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000000000000022222333332',
  salt: '0x88888888888888888888888888888888',
  token: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  amount: '0x0000000000000000000055555555555555555555555555555555555555555555',
  pubKey: alicePubKey
});

const utxo2_out_2: UTXO = new UTXO({
  eth: '0x00',
  salt: '0x99999999999999999999999999999999',
  token: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  amount: '0x0000000000000000000033333333333333333333333333333333333333333333',
  pubKey: bobPubKey
});

const utxo2_out_3: UTXO = new UTXO({
  eth: '0x00',
  salt: '0x33333333333333333333333333333333',
  token: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  nft: '0x9178917891789178917891789178917891789178917891789178917891789178',
  pubKey: alicePubKey
});

const utxo2_out_4: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000007777777777777777776',
  salt: '0x44444444444444444444444444444444',
  pubKey: bobPubKey
});

const utxo3_in_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000001111111111111111111',
  salt: '0x55555555555555555444444444444444',
  pubKey: alicePubKey
});

const utxo3_in_2: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000002222222222222222222',
  salt: '0x33333333333335555444444444444444',
  pubKey: alicePubKey
});

const utxo3_in_3: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000003333333333333333333',
  salt: '0x22222255555555555444444444444444',
  pubKey: alicePubKey
});

const utxo3_out_1: UTXO = new UTXO({
  eth: '0x0000000000000000000000000000000000000000000006666666666666666666',
  salt: '0x55555555555555555444444447777777',
  pubKey: alicePubKey
});

merkleTree.update(0, utxo1_in_1);
merkleTree.update(1, utxo2_in_1);
merkleTree.update(2, utxo2_in_2);

let prevUTXORoot1;
let prevUTXORoot2;
(async () => {
  prevUTXORoot1 = await merkleTree.root();
})();
merkleTree.update(3, utxo3_in_1);
merkleTree.update(4, utxo3_in_2);
merkleTree.update(5, utxo3_in_3);
(async () => {
  prevUTXORoot2 = await merkleTree.root();
})();

const tx_1: ZkTransaction = {
  inflow: [{ nullifier: utxo1_in_1.nullifier(0), root: prevUTXORoot1 }],
  outflow: [{ note: utxo1_out_1.hash() }, { note: utxo1_out_2.hash() }],
  fee: '0x01',
  proof: { pi_a: [], pi_b: [[]], pi_c: [] }
};

const tx_2_1: ZkTransaction = {
  inflow: [{ nullifier: utxo2_in_1.nullifier(1), root: prevUTXORoot1 }],
  outflow: [{ note: utxo2_out_1.hash() }, { note: utxo2_out_2.hash() }],
  swap: utxo2_out_3.hash(),
  fee: '0x01',
  proof: { pi_a: [], pi_b: [[]], pi_c: [] }
};

const tx_2_2: ZkTransaction = {
  inflow: [{ nullifier: utxo2_in_2.nullifier(2), root: prevUTXORoot1 }],
  outflow: [{ note: utxo2_out_3.hash() }, { note: utxo2_out_4.hash() }],
  swap: utxo2_out_2.hash(),
  fee: '0x01',
  proof: { pi_a: [], pi_b: [[]], pi_c: [] }
};

/**
const utxo1 = {
    eth: '0x0000000000000000000000000000000000000000000000000000011111111111',
    salt: '0x94efd282e2450bab4c8b7c977cfd30e3a3b5632e3223cd2ff9ff322a12328caf',
    address: '0x00',
    address: '0x00',
    address: '0x00',
    address: '0x00',

        uint eth,
        uint salt,
        address token,
        uint amount,
        uint nft,
        uint[2] memory pubKey,
}


const Tx1 = {
    inflows: [
        {
            root: '0x1111111111111111111111111111111111111111111111111111111111111111',
            nullifier: '0x1cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
        },
        {
            root: '0x2222222222222222222222222222222222222222222222222222222222222222',
            nullifier: '0x2cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
        },
    ],
    outflows: [
        {
            note: '0x3333333333333333333333333333333333333333333333333333333333333333',
        },
        {
            note: '0x3333333333333333333333333333333333333333333333333333333333333333',
            data: {
                to: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                eth: '0x0000000000000000000000000000000000001111111111111111111111111111',
                token: '0xcccccccccccccccccccccccccccccccccccccccc',
                amount: '0x0000000000000000000000000000000000000000000000000022222222222222',
                nft: '0x0000000000000000000000000000000000000000000000000000000000000000',
                fee: '0x0000000000000000000000000000000000000000000000000000000000001111',
            }
        },
        {
            note: '0x3333333333333333333333333333333333333333333333333333333333333333',
            data: {
                to: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                eth: '0x0000000000000000000000000000000000001111111111111111111111111111',
                token: '0xcccccccccccccccccccccccccccccccccccccccc',
                amount: '0x0000000000000000000000000000000000000000000000000022222222222222',
                nft: '0x0000000000000000000000000000000000000000000000000000000000000000',
                fee: '0x0000000000000000000000000000000000000000000000000000000000001111',
            }
        },
    ]
}


const data = {
  metadata: {
    address: '0xabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd',
    prev: {
      output: '0x1cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
      nullifier: '0x2cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
      withdrawal: '0x3cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
    },
    next: {
      output: '0x4cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
      nullifier: '0x5cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
      withdrawal: '0x6cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
    },
    numberOfTxs: '0x0002',
    numberOfDeposits: '0x0002',
    totalFee: '0x000000000000000000000000000000000000000000000000000000000000000f'
  },
  deposits: ['0x4cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde', '0x4cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'],
  transactions: [
    {
      numOfInputs: '0x02',
      numOfOutputs: '0x02',
      txType: '0x00',
      fee: '0x1111111111111111111111111111111111111111111111111111111111111111',
      inclusionRefs: [
        '0x7cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x8cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
      ],
      nullifiers: ['0x9cdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde', '0x10debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'],
      outputs: ['0x11debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde', '0x12debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'],
      proofs: [
        '0x131ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x132ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x133ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x134ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x135ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x136ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x137ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x138ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
      ]
    },
    {
      numOfInputs: '0x02',
      numOfOutputs: '0x02',
      txType: '0x00',
      fee: '0x12',
      inclusionRefs: [
        '0x14aebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x14bebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
      ],
      nullifiers: ['0x14cebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde', '0x14debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'],
      outputs: ['0x15debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde', '0x15debcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'],
      proofs: [
        '0x161ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x162ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x163ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x164ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x165ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x166ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x167ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde',
        '0x168ebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcdebcde'
      ]
    }
  ]
};

const combine = arr => {
  let result = '0x';
  for (let i = 0; i < arr.length; i++) {
    result = result.concat(arr[i].slice(2));
  }
  return result;
};
const serialized = combine([
  data.metadata.address,
  data.metadata.prev.output,
  data.metadata.prev.nullifier,
  data.metadata.prev.withdrawal,
  data.metadata.next.output,
  data.metadata.next.nullifier,
  data.metadata.next.withdrawal,
  data.metadata.numberOfTxs,
  data.metadata.numberOfDeposits,
  data.metadata.totalFee,
  ...data.deposits,
  ...data.transactions.map(tx =>
    combine([tx.numOfInputs, tx.numOfOutputs, tx.txType, tx.fee, ...tx.inclusionRefs, ...tx.nullifiers, ...tx.outputs, ...tx.proofs])
  )
]);
 */
