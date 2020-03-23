import { loadGrove, loadCircuits, txs, loadPrebuiltZkTxs } from '../dataset/dataset';
import { keys } from '../dataset/dataset';
import { expect } from 'chai';
import { ZkWizard } from '../../src/zk_wizard';
import { Grove } from '../../src/tree';
import { ZkTransaction } from '../../src/zk_transaction';
import fs from 'fs';

context('zk SNARK', () => {
  let preset: {
    grove: Grove;
    close: () => Promise<void>;
  };
  let aliceZkWizard: ZkWizard;
  let bobZkWizard: ZkWizard;
  let zkTxs: ZkTransaction[];
  before('Prepare data and circuits', async () => {
    preset = await loadGrove();
    aliceZkWizard = new ZkWizard({
      grove: preset.grove,
      privKey: keys.alicePrivKey
    });
    let { circuit_1_2, circuit_1_2_pk, circuit_3_1, circuit_3_1_pk, circuit_3_3, circuit_3_3_pk } = loadCircuits();
    aliceZkWizard.addCircuit({
      n_i: 1,
      n_o: 2,
      circuitDef: circuit_1_2,
      provingKey: circuit_1_2_pk
    });
    aliceZkWizard.addCircuit({
      n_i: 3,
      n_o: 1,
      circuitDef: circuit_3_1,
      provingKey: circuit_3_1_pk
    });
    aliceZkWizard.addCircuit({
      n_i: 3,
      n_o: 3,
      circuitDef: circuit_3_3,
      provingKey: circuit_3_3_pk
    });
    bobZkWizard = new ZkWizard({
      grove: preset.grove,
      privKey: keys.bobPrivKey
    });
    bobZkWizard.addCircuit({
      n_i: 1,
      n_o: 2,
      circuitDef: circuit_1_2,
      provingKey: circuit_1_2_pk
    });
    zkTxs = [];
  });
  context('class ZkWizard @ zk_wizard.js', () => {
    describe.skip('shield()', () => {
      it('should create a zk transaction from a normal transaction', async () => {
        let zk_tx_1 = await aliceZkWizard.shield({ tx: txs.tx_1, toMemo: 0 });
        zkTxs.push(zk_tx_1);
        fs.writeFileSync('data/txs/zk_tx_1.tx', zk_tx_1.encode());
      });
      it('should create a zk transaction from a normal transaction', async () => {
        let zk_tx_2_1 = await aliceZkWizard.shield({ tx: txs.tx_2_1, toMemo: 1 });
        zkTxs.push(zk_tx_2_1);
        fs.writeFileSync('data/txs/zk_tx_2_1.tx', zk_tx_2_1.encode());
      });
      it('should create a zk transaction from a normal transaction', async () => {
        let zk_tx_2_2 = await bobZkWizard.shield({ tx: txs.tx_2_2, toMemo: 1 });
        zkTxs.push(zk_tx_2_2);
        fs.writeFileSync('data/txs/zk_tx_2_2.tx', zk_tx_2_2.encode());
      });
      it('should create a zk transaction from a normal transaction', async () => {
        let zk_tx_3 = await aliceZkWizard.shield({ tx: txs.tx_3 });
        zkTxs.push(zk_tx_3);
        fs.writeFileSync('data/txs/zk_tx_3.tx', zk_tx_3.encode());
      });
      it('should create a zk transaction from a normal transaction', async () => {
        let zk_tx_4 = await aliceZkWizard.shield({ tx: txs.tx_4 });
        zkTxs.push(zk_tx_4);
        fs.writeFileSync('data/txs/zk_tx_4.tx', zk_tx_4.encode());
      });
    });
    after('Using prebuilt zk txs for quick test', () => {
      zkTxs = loadPrebuiltZkTxs();
    });
  });
  context('class ZkTransaction @ zk_transaction.js', () => {
    let encoded: Buffer[];
    let decoded: ZkTransaction[];
    describe('encode()', () => {
      it('should be serialized in a compact way.', () => {
        encoded = zkTxs.map(zkTx => zkTx.encode());
      }),
        it.skip('should be decodable in solidity', () => {});
    });
    describe('static decode()', () => {
      it('should be retrieved from serialized bytes data', () => {
        decoded = encoded.map(ZkTransaction.decode);
        expect(decoded[0].hash()).to.eq(zkTxs[0].hash());
        expect(decoded[1].hash()).to.eq(zkTxs[1].hash());
        expect(decoded[2].hash()).to.eq(zkTxs[2].hash());
        expect(decoded[3].hash()).to.eq(zkTxs[3].hash());
        expect(decoded[4].hash()).to.eq(zkTxs[4].hash());
      });
    });
    describe('hash()', () => {
      it.skip('should return same hash value with the solidity hash function', () => {});
    });
  });
  after(async () => {
    await preset.close();
  });
});
