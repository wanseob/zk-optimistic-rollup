import { loadPrebuiltZkTxs, buildAndSaveZkTxs } from '../dataset/dataset';
import { ZkTransaction } from '../../src/zk_transaction';
import { TxMemPool } from '../../src/coordinator';
import { expect } from 'chai';
import fs from 'fs';

context('Coordinator test', () => {
  let zkTxs: ZkTransaction[];
  let txPool: TxMemPool = new TxMemPool();
  before('Initialize data set for test', async () => {
    // await buildAndSaveZkTxs();
    zkTxs = loadPrebuiltZkTxs();
  });
  context('TxMemPool', () => {
    before(() => {
      let circuit_1_2_vk = JSON.parse(fs.readFileSync('build/vks.test/zk_transaction_1_2.test.vk.json', 'utf8'));
      let circuit_3_1_vk = JSON.parse(fs.readFileSync('build/vks.test/zk_transaction_3_1.test.vk.json', 'utf8'));
      let circuit_3_3_vk = JSON.parse(fs.readFileSync('build/vks.test/zk_transaction_3_3.test.vk.json', 'utf8'));
      txPool.addVerifier({ n_i: 1, n_o: 2, vk: circuit_1_2_vk });
      txPool.addVerifier({ n_i: 3, n_o: 1, vk: circuit_3_1_vk });
      txPool.addVerifier({ n_i: 3, n_o: 3, vk: circuit_3_3_vk });
    });
    describe('addToTxPool()', () => {
      it('should add txs to the "pending" tx mem pool', async () => {
        txPool.addToTxPool(zkTxs[0]);
        txPool.addToTxPool(zkTxs[1]);
        txPool.addToTxPool(zkTxs[2]);
        txPool.addToTxPool(zkTxs[3]);
        txPool.addToTxPool(zkTxs[4]);
        expect(txPool.pendingNum()).to.eq(5);
      });
    });
    let candidates: ZkTransaction[];
    describe('pickPendingTxs()', () => {
      it('should pick transactions less than the given limit size', () => {
        candidates = txPool.pickPendingTxs(2048);
        expect(candidates.reduce((size, zkTx) => size + zkTx.size(), 0)).to.be.lessThan(2048);
      });
    });
  });
});
