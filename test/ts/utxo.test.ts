import { Field } from '../../src/field';
import { UTXO } from '../../src/utxo';
import { keys, address, nfts } from '../dataset/dataset';
import { expect } from 'chai';
import * as snarkjs from 'snarkjs';
import fs from 'fs';

context('utxo.js: class UTXO', () => {
  context('Static functions', () => {
    describe('UTXO.newEtherNote()', async () => {
      let utxo: UTXO;
      let ETH_AMOUNT: number = 1234;
      before(() => {
        utxo = UTXO.newEtherNote({
          eth: ETH_AMOUNT,
          pubKey: keys.alicePubKey
        });
      });
      it('should have same the given amount of Ether', async () => {
        expect(utxo.eth.equal(Field.from(ETH_AMOUNT))).to.eq(true);
      });
      it('should return 0 for its token address value', async () => {
        expect(utxo.tokenAddr.isZero()).to.eq(true);
      });
      it('should have the same Pubkey with the input pub key', async () => {
        expect(utxo.pubKey.x.equal(keys.alicePubKey.x)).to.eq(true);
        expect(utxo.pubKey.y.equal(keys.alicePubKey.y)).to.eq(true);
      });
      it('should have zero ERC20 amount', async () => {
        expect(utxo.erc20Amount.isZero()).to.eq(true);
      });
      it('should return 0 for its NFT id', async () => {
        expect(utxo.nft.isZero()).to.eq(true);
      });
      it('should have no public data', async () => {
        expect(utxo.publicData).to.eq(undefined);
      });
      it('should make it return 0 for its outflow type.', () => {
        expect(utxo.outflowType().isZero()).to.eq(true);
      });
    });
    describe('UTXO.newERC20Note()', async () => {
      let utxo: UTXO;
      let TOKEN_ADDR: string = address.DAI;
      let DAI_AMOUNT: number = 8126534;
      before(() => {
        utxo = UTXO.newERC20Note({
          eth: 0,
          tokenAddr: TOKEN_ADDR,
          erc20Amount: DAI_AMOUNT,
          pubKey: keys.alicePubKey
        });
      });
      it('should have zero Ether', async () => {
        expect(utxo.eth.isZero()).to.eq(true);
      });
      it('should have the given token address', async () => {
        expect(utxo.tokenAddr.equal(Field.from(TOKEN_ADDR))).to.eq(true);
      });
      it('should have the same Pubkey with the input pub key', async () => {
        expect(utxo.pubKey.x.equal(keys.alicePubKey.x)).to.eq(true);
        expect(utxo.pubKey.y.equal(keys.alicePubKey.y)).to.eq(true);
      });
      it('should have then given ERC20 amount', async () => {
        expect(utxo.erc20Amount.equal(Field.from(DAI_AMOUNT))).to.eq(true);
      });
      it('should return 0 for its NFT id', async () => {
        expect(utxo.nft.isZero()).to.eq(true);
      });
      it('should have no public data', async () => {
        expect(utxo.publicData).to.eq(undefined);
      });
      it('should make it return 0 for its outflow type.', () => {
        expect(utxo.outflowType().isZero()).to.eq(true);
      });
    });
    describe('UTXO.newNFTNote()', async () => {
      let utxo: UTXO;
      let TOKEN_ADDR: string = address.CRYPTO_KITTIES;
      let NFT_ID: string = nfts.KITTY_1;
      before(() => {
        utxo = UTXO.newNFTNote({
          eth: 0,
          tokenAddr: TOKEN_ADDR,
          nft: NFT_ID,
          pubKey: keys.alicePubKey
        });
      });
      it('should have zero Ether', async () => {
        expect(utxo.eth.isZero()).to.eq(true);
      });
      it('should have the given token address', async () => {
        expect(utxo.tokenAddr.equal(Field.from(TOKEN_ADDR))).to.eq(true);
      });
      it('should have the same Pubkey with the input pub key', async () => {
        expect(utxo.pubKey.x.equal(keys.alicePubKey.x)).to.eq(true);
        expect(utxo.pubKey.y.equal(keys.alicePubKey.y)).to.eq(true);
      });
      it('should have zero amount of ERC20', async () => {
        expect(utxo.erc20Amount.isZero()).to.eq(true);
      });
      it('should have the given NFT id', async () => {
        expect(utxo.nft.equal(Field.from(NFT_ID))).to.eq(true);
      });
      it('should have no public data', async () => {
        expect(utxo.publicData).to.eq(undefined);
      });
      it('should make it return 0 for its outflow type.', () => {
        expect(utxo.outflowType().isZero()).to.eq(true);
      });
    });
  });
  context('Member functions', () => {
    let utxo1: UTXO;
    let utxo2: UTXO;
    let utxo3: UTXO;
    let ETH_AMOUNT: number = 1234;
    let ERC20_ADDR: string = address.DAI;
    let DAI_AMOUNT: number = 8126534;
    let NFT_ADDR: string = address.CRYPTO_KITTIES;
    let NFT_ID: string = nfts.KITTY_1;
    beforeEach(() => {
      utxo1 = UTXO.newEtherNote({
        eth: ETH_AMOUNT,
        pubKey: keys.alicePubKey
      });
      utxo2 = UTXO.newERC20Note({
        eth: 0,
        tokenAddr: ERC20_ADDR,
        erc20Amount: DAI_AMOUNT,
        pubKey: keys.alicePubKey
      });
      utxo3 = UTXO.newNFTNote({
        eth: 0,
        tokenAddr: NFT_ADDR,
        nft: NFT_ID,
        pubKey: keys.alicePubKey
      });
    });
    describe('markAsWithdrawal()', () => {
      it('should make it have public data.', () => {
        expect(utxo1.publicData).to.equal(undefined);
        expect(utxo2.publicData).to.equal(undefined);
        expect(utxo3.publicData).to.equal(undefined);
        utxo1.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo2.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo3.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        expect(utxo1.publicData).not.to.equal(undefined);
        expect(utxo2.publicData).not.to.equal(undefined);
        expect(utxo3.publicData).not.to.equal(undefined);
      });
      it('should make it return 1 for its outflow type.', () => {
        expect(utxo1.outflowType().isZero()).to.eq(true);
        expect(utxo2.outflowType().isZero()).to.eq(true);
        expect(utxo3.outflowType().isZero()).to.eq(true);
        utxo1.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo2.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo3.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        expect(utxo1.outflowType().equal(Field.from(1))).to.eq(true);
        expect(utxo2.outflowType().equal(Field.from(1))).to.eq(true);
        expect(utxo3.outflowType().equal(Field.from(1))).to.eq(true);
      });
      it('should not change its hash() or nullifier() result', () => {
        let prevUTXO1Hash = utxo1.hash();
        let prevUTXO2Hash = utxo2.hash();
        let prevUTXO3Hash = utxo3.hash();
        let prevUTXO1Nullifier = utxo1.nullifier();
        let prevUTXO2Nullifier = utxo2.nullifier();
        let prevUTXO3Nullifier = utxo3.nullifier();
        utxo1.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo2.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        utxo3.markAsWithdrawal({ to: address.USER_A, fee: 1 });
        let nextUTXO1Hash = utxo1.hash();
        let nextUTXO2Hash = utxo2.hash();
        let nextUTXO3Hash = utxo3.hash();
        let nextUTXO1Nullifier = utxo1.nullifier();
        let nextUTXO2Nullifier = utxo2.nullifier();
        let nextUTXO3Nullifier = utxo3.nullifier();
        expect(prevUTXO1Hash.equal(nextUTXO1Hash));
        expect(prevUTXO2Hash.equal(nextUTXO2Hash));
        expect(prevUTXO3Hash.equal(nextUTXO3Hash));
        expect(prevUTXO1Nullifier.equal(nextUTXO1Nullifier));
        expect(prevUTXO2Nullifier.equal(nextUTXO2Nullifier));
        expect(prevUTXO3Nullifier.equal(nextUTXO3Nullifier));
      });
    });
    describe('markAsMigration()', () => {
      it('should make it have public data.', () => {
        expect(utxo1.publicData).to.equal(undefined);
        expect(utxo2.publicData).to.equal(undefined);
        expect(utxo3.publicData).to.equal(undefined);
        utxo1.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo2.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo3.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        expect(utxo1.publicData).not.to.equal(undefined);
        expect(utxo2.publicData).not.to.equal(undefined);
        expect(utxo3.publicData).not.to.equal(undefined);
      });
      it('should make it return 2 for its outflow type.', () => {
        expect(utxo1.outflowType().isZero()).to.eq(true);
        expect(utxo2.outflowType().isZero()).to.eq(true);
        expect(utxo3.outflowType().isZero()).to.eq(true);
        utxo1.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo2.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo3.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        expect(utxo1.outflowType().equal(Field.from(2))).to.eq(true);
        expect(utxo2.outflowType().equal(Field.from(2))).to.eq(true);
        expect(utxo3.outflowType().equal(Field.from(2))).to.eq(true);
      });
      it('should not change its hash() or nullifier() result', () => {
        let prevUTXO1Hash = utxo1.hash();
        let prevUTXO2Hash = utxo2.hash();
        let prevUTXO3Hash = utxo3.hash();
        let prevUTXO1Nullifier = utxo1.nullifier();
        let prevUTXO2Nullifier = utxo2.nullifier();
        let prevUTXO3Nullifier = utxo3.nullifier();
        utxo1.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo2.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        utxo3.markAsMigration({ to: address.CONTRACT_B, fee: 1 });
        let nextUTXO1Hash = utxo1.hash();
        let nextUTXO2Hash = utxo2.hash();
        let nextUTXO3Hash = utxo3.hash();
        let nextUTXO1Nullifier = utxo1.nullifier();
        let nextUTXO2Nullifier = utxo2.nullifier();
        let nextUTXO3Nullifier = utxo3.nullifier();
        expect(prevUTXO1Hash.equal(nextUTXO1Hash));
        expect(prevUTXO2Hash.equal(nextUTXO2Hash));
        expect(prevUTXO3Hash.equal(nextUTXO3Hash));
        expect(prevUTXO1Nullifier.equal(nextUTXO1Nullifier));
        expect(prevUTXO2Nullifier.equal(nextUTXO2Nullifier));
        expect(prevUTXO3Nullifier.equal(nextUTXO3Nullifier));
      });
    });
    describe.skip('hash()', () => {
      it('should return same result with the NoteHash() circuit', () => {
        let input1 = {
          eth: utxo1.eth,
          pubkey_x: utxo1.pubKey.x,
          pubkey_y: utxo1.pubKey.y,
          salt: utxo1.salt,
          token_addr: utxo1.tokenAddr,
          erc20: utxo1.erc20Amount,
          nft: utxo1.nft
        };
        let input2 = {
          eth: utxo2.eth,
          pubkey_x: utxo2.pubKey.x,
          pubkey_y: utxo2.pubKey.y,
          salt: utxo2.salt,
          token_addr: utxo2.tokenAddr,
          erc20: utxo2.erc20Amount,
          nft: utxo2.nft
        };
        let input3 = {
          eth: utxo3.eth,
          pubkey_x: utxo3.pubKey.x,
          pubkey_y: utxo3.pubKey.y,
          salt: utxo3.salt,
          token_addr: utxo3.tokenAddr,
          erc20: utxo3.erc20Amount,
          nft: utxo3.nft
        };
        Object.keys(input1).forEach(key => {
          input1[key] = input1[key].toString();
        });
        Object.keys(input2).forEach(key => {
          input2[key] = input2[key].toString();
        });
        Object.keys(input3).forEach(key => {
          input3[key] = input3[key].toString();
        });

        let noteHashCircuit = JSON.parse(fs.readFileSync('build/circuits.test/note_hash.test.json', 'utf8'));
        let noteHashProvingKey = JSON.parse(fs.readFileSync('build/pks.test/note_hash.test.pk.json', 'utf8'));
        let circuit = new snarkjs.Circuit(noteHashCircuit);
        let witness1 = circuit.calculateWitness(input1);
        let witness2 = circuit.calculateWitness(input2);
        let witness3 = circuit.calculateWitness(input3);
        let pk = snarkjs.unstringifyBigInts(noteHashProvingKey);
        let result1 = snarkjs.groth.genProof(pk, witness1);
        let result2 = snarkjs.groth.genProof(pk, witness2);
        let result3 = snarkjs.groth.genProof(pk, witness3);
        expect(utxo1.hash().equal(result1.publicSignals[0])).to.eq(true);
        expect(utxo2.hash().equal(result2.publicSignals[0])).to.eq(true);
        expect(utxo3.hash().equal(result3.publicSignals[0])).to.eq(true);
      });
    });
    describe.skip('nullifier()', () => {
      it('should return same result with the Nullifier() circuit', async () => {
        let input1 = {
          note_hash: utxo1.hash(),
          note_salt: utxo1.salt
        };
        let input2 = {
          note_hash: utxo2.hash(),
          note_salt: utxo2.salt
        };
        let input3 = {
          note_hash: utxo3.hash(),
          note_salt: utxo3.salt
        };
        Object.keys(input1).forEach(key => {
          input1[key] = input1[key].toString();
        });
        Object.keys(input2).forEach(key => {
          input2[key] = input2[key].toString();
        });
        Object.keys(input3).forEach(key => {
          input3[key] = input3[key].toString();
        });
        let nullifierCircuit = JSON.parse(fs.readFileSync('build/circuits.test/nullifier.test.json', 'utf8'));
        let nullifierProvingKey = JSON.parse(fs.readFileSync('build/pks.test/nullifier.test.pk.json', 'utf8'));
        let circuit = new snarkjs.Circuit(nullifierCircuit);
        let witness1 = circuit.calculateWitness(input1);
        let witness2 = circuit.calculateWitness(input2);
        let witness3 = circuit.calculateWitness(input3);
        let pk = snarkjs.unstringifyBigInts(nullifierProvingKey);
        let result1 = snarkjs.groth.genProof(pk, witness1);
        let result2 = snarkjs.groth.genProof(pk, witness2);
        let result3 = snarkjs.groth.genProof(pk, witness3);
        expect(utxo1.nullifier().equal(result1.publicSignals[0])).to.eq(true);
        expect(utxo2.nullifier().equal(result2.publicSignals[0])).to.eq(true);
        expect(utxo3.nullifier().equal(result3.publicSignals[0])).to.eq(true);
      });
    });
    describe('encrypt()', () => {
      it("should encrypt the UTXO into 81 bytes size data using owner's pub key.", () => {
        expect(utxo1.encrypt().length).to.eq(81);
      });
      it('should be decryptable by the private key of the owner', () => {
        let utxoHash = utxo1.hash();
        let encrypted = utxo1.encrypt();
        let decryptedUTXO = UTXO.decrypt({
          utxoHash,
          memo: encrypted,
          privKey: keys.alicePrivKey
        });
        expect(decryptedUTXO.hash().equal(utxoHash)).to.eq(true);
      });
      it('should not be decryptable with incorrect private key', () => {
        let utxoHash = utxo1.hash();
        let encrypted = utxo1.encrypt();
        expect(() =>
          UTXO.decrypt({
            utxoHash,
            memo: encrypted,
            privKey: keys.bobPrivKey
          })
        ).to.throw();
      });
    });
  });
});
