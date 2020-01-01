// import chai from 'chai';
// import { soliditySha3 } from 'web3-utils';
// import fs from 'fs-extra';

// const expect = chai.expect;
const OptimisticSNARKsRollUp = artifacts.require('OptimisticSNARKsRollUp');

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

contract('Simple tests', async accounts => {
  before(async () => {
    rollUpLib = await OptimisticSNARKsRollUp.new();
  });
});
