import { TxBuilder } from '../../src/transaction';
import { keys, utxos as u, address, nfts } from '../dataset/dataset';
import { Field } from '../../src/field';
import { expect } from 'chai';
import { BabyJubjub } from '../../src/jubjub';

context('transaction.ts:', () => {
  context('class TxBuilder', () => {
    describe('spendable()', () => {
      it('should return exact amount of spendable eth', async () => {
        let txBuilder = TxBuilder.from(keys.alicePubKey);
        const FEE = 1;
        let spendable = txBuilder
          .fee(FEE)
          .spend(u.utxo3_in_1)
          .spend(u.utxo3_in_2)
          .spend(u.utxo3_in_3)
          .spendable();
        let expectedETH = u.utxo3_in_1.eth
          .add(u.utxo3_in_2.eth)
          .add(u.utxo3_in_3.eth)
          .sub(Field.from(FEE));
        expect(spendable.eth.equal(expectedETH)).to.eq(true);
      });
      it('should return exact amount of spendable erc20', async () => {
        let txBuilder = TxBuilder.from(keys.alicePubKey);
        const FEE = 1;
        let spendable = txBuilder
          .fee(FEE)
          .spend(u.utxo2_1_in_1)
          .spendable();
        expect(spendable.erc20[u.utxo2_1_in_1.tokenAddr.toHex()].equal(u.utxo2_1_in_1.erc20Amount)).to.eq(true);
      });
      it('should return exact spendable nft ids', async () => {
        let txBuilder = TxBuilder.from(keys.bobPubKey);
        const FEE = 1;
        let spendable = txBuilder
          .fee(FEE)
          .spend(u.utxo2_2_in_1)
          .spendable();
        expect(spendable.erc721[u.utxo2_2_in_1.tokenAddr.toHex()].find(nft => nft.equal(u.utxo2_2_in_1.nft))).not.to.eq(undefined);
      });
    });
    describe('build()', () => {
      it('should return Tx object', async () => {
        let tx = TxBuilder.from(keys.alicePubKey)
          .fee(1)
          .spend(u.utxo1_in_1)
          .sendEther({
            eth: 2222,
            to: keys.bobPubKey
          })
          .build();
        expect(tx).exist;
      });
      it('should return Tx object for atomic swap', async () => {
        let tx = TxBuilder.from(keys.alicePubKey)
          .fee(1)
          .spend(u.utxo2_1_in_1)
          .sendERC20({
            tokenAddr: address.DAI,
            erc20Amount: 3333,
            to: keys.bobPubKey
          })
          .swapForNFT({
            tokenAddr: address.CRYPTO_KITTIES,
            nft: nfts.KITTY_1
          })
          .build();
        expect(tx).exist;
      });
      it('should return Tx object for withdrawal', async () => {
        let tx = TxBuilder.from(keys.alicePubKey)
          .fee(1)
          .spend(u.utxo3_in_1)
          .spend(u.utxo3_in_2)
          .spend(u.utxo3_in_3)
          .sendEther({
            eth: 555555555555555,
            to: BabyJubjub.Point.zero,
            withdrawal: {
              to: address.USER_A,
              fee: 1
            }
          })
          .build();
        expect(tx).exist;
      });
      it('should return Tx object for migration', async () => {
        let tx = TxBuilder.from(keys.alicePubKey)
          .fee(1)
          .spend(u.utxo4_in_1)
          .spend(u.utxo4_in_2)
          .spend(u.utxo4_in_3)
          .sendEther({
            eth: 8888888888884,
            to: keys.alicePubKey,
            migration: {
              to: address.CONTRACT_B,
              fee: 1
            }
          })
          .sendERC20({
            tokenAddr: address.DAI,
            erc20Amount: 5555,
            to: keys.alicePubKey,
            migration: {
              to: address.CONTRACT_B,
              fee: 1
            }
          })
          .sendNFT({
            tokenAddr: address.CRYPTO_KITTIES,
            nft: nfts.KITTY_2,
            to: keys.alicePubKey,
            migration: {
              to: address.CONTRACT_B,
              fee: 1
            }
          })
          .build();
        expect(tx).exist;
      });
    });
  });
});
