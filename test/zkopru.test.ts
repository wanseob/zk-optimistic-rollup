import { BabyJubjub } from '../src/jubjub';
import semaphore from 'semaphore-merkle-tree';
import { keys, utxos, txs, TestSet, loadTestSet } from '../data/testset';
import { UTXOGrove } from '../src/tree';
import { ZkTransaction, TxBuilder, ZkWizard } from '../src/transaction';
import { TokenAddress } from '../src/tokens';
import { Field } from '../src/field';
import { UTXO } from '../src/utxo';
import { soliditySha3 } from 'web3-utils';
import chai from 'chai';
import fs from 'fs-extra';

const expect = chai.expect;

context('Zk Optimistic Rollup', () => {
  let testSet: TestSet;
  before(async () => {
    let grovePath = 'build/1.tree';
    let txPaths = ['build/txs/zk_tx_1.tx', 'build/txs/zk_tx_2_1.tx', 'build/txs/zk_tx_2_2.tx', 'build/txs/zk_tx_3.tx', 'build/txs/zk_tx_4.tx'];
    testSet = await loadTestSet('build/1.tree');
  });
  describe('NullifierTree', () => {
    it('should hey', async () => {});
  });
});
