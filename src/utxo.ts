import { Hex, randomHex } from 'web3-utils';

import * as circomlib from 'circomlib';
import { BabyJubjub } from './jubjub';
import { Field } from './field';
import * as chacha20 from 'chacha20';
import { getTokenId, getTokenAddress } from './tokens';
import { Outflow, PublicData } from './transaction';

const poseidonHash = circomlib.poseidon.createHash(6, 8, 57, 'poseidon');

export class UTXO {
  eth: Field;
  pubKey: BabyJubjub.Point;
  salt: Field;
  tokenAddr: Field;
  erc20Amount: Field;
  nft: Field;
  publicData?: {
    isWithdrawal: boolean;
    to: Field;
    fee: Field;
  };

  constructor(eth: Field, salt: Field, tokenAddr: Field, erc20Amount: Field, nft: Field, pubKey: BabyJubjub.Point, migrationTo?: Field) {
    this.eth = eth;
    this.pubKey = pubKey;
    this.salt = salt;
    this.tokenAddr = tokenAddr;
    this.erc20Amount = erc20Amount;
    this.nft = nft;
  }

  static newEtherNote({ eth, pubKey, salt }: { eth: Hex | Field; pubKey: BabyJubjub.Point; salt?: Hex | Field }): UTXO {
    salt = salt ? Field.from(salt) : Field.from(randomHex(16));
    return new UTXO(Field.from(eth), salt, Field.from(0), Field.from(0), Field.from(0), pubKey);
  }

  static newERC20Note({
    eth,
    tokenAddr,
    erc20Amount,
    pubKey,
    salt
  }: {
    eth: Hex | Field;
    tokenAddr: Hex | Field;
    erc20Amount: Hex | Field;
    pubKey: BabyJubjub.Point;
    salt?: Hex | Field;
  }): UTXO {
    salt = salt ? Field.from(salt) : Field.from(randomHex(16));
    return new UTXO(Field.from(eth), salt, Field.from(tokenAddr), Field.from(erc20Amount), Field.from(0), pubKey);
  }

  static newNFTNote({
    eth,
    tokenAddr,
    nft,
    pubKey,
    salt
  }: {
    eth: Hex | Field;
    tokenAddr: Hex | Field;
    nft: Hex | Field;
    pubKey: BabyJubjub.Point;
    salt?: Hex | Field;
  }): UTXO {
    salt = salt ? Field.from(salt) : Field.from(randomHex(16));
    return new UTXO(Field.from(eth), salt, Field.from(tokenAddr), Field.from(0), Field.from(nft), pubKey);
  }

  markAsWithdrawal({ to, fee }: { to: Hex | Field; fee: Hex | Field }) {
    this.publicData = { isWithdrawal: true, to: Field.from(to), fee: Field.from(fee) };
  }

  markAsMigration({ to, fee }: { to: Hex | Field; fee: Hex | Field }) {
    this.publicData = { isWithdrawal: false, to: Field.from(to), fee: Field.from(fee) };
  }

  markAsInternalUtxo() {
    this.publicData = undefined;
  }

  hash(): Field {
    let firstHash = Field.from(poseidonHash([this.eth.val, this.pubKey.x.val, this.pubKey.y, this.salt.val]));
    let resultHash = Field.from(poseidonHash([firstHash, this.tokenAddr.val, this.erc20Amount.val, this.nft.val]));
    return resultHash;
  }

  nullifier(): Field {
    return Field.from(poseidonHash([this.hash(), this.salt.val]));
  }

  encrypt(): Buffer {
    let ephemeralSecretKey: Field = Field.from(randomHex(16));
    let sharedKey: Buffer = this.pubKey.mul(ephemeralSecretKey).encode();
    let tokenId = getTokenId(this.tokenAddr);
    let value = this.eth ? this.eth : this.erc20Amount ? this.erc20Amount : this.nft;
    let secret = [this.salt.toBuffer(16), Field.from(tokenId).toBuffer(1), value.toBuffer(32)];
    let ciphertext = chacha20.encrypt(sharedKey, 0, Buffer.concat(secret));
    let encryptedMemo = Buffer.concat([BabyJubjub.Point.generate(ephemeralSecretKey).encode(), ciphertext]);
    // 32bytes ephemeral pub key + 16 bytes salt + 1 byte token id + 32 bytes value = 81 bytes
    return encryptedMemo;
  }

  toOutflow(): Outflow {
    let data: PublicData;
    if (this.publicData) {
      data = {
        to: this.publicData.to,
        eth: this.eth,
        tokenAddr: this.tokenAddr,
        erc20Amount: this.erc20Amount,
        nft: this.nft,
        fee: this.publicData.fee
      };
    }
    let outflow = {
      note: this.hash(),
      outflowType: this.outflowType(),
      data
    };
    return outflow;
  }

  toJSON(): string {
    return JSON.stringify({
      eth: this.eth,
      salt: this.salt,
      token: this.tokenAddr,
      amount: this.erc20Amount,
      nft: this.nft.toHex(),
      pubKey: {
        x: this.pubKey.x,
        y: this.pubKey.y
      }
    });
  }

  outflowType(): Field {
    if (this.publicData) {
      if (this.publicData.isWithdrawal) {
        return Field.from(1); // Withdrawal
      } else {
        return Field.from(2); // Migration
      }
    } else {
      return Field.from(0); // UTXO
    }
  }

  static fromJSON(data: string): UTXO {
    let obj = JSON.parse(data);
    return new UTXO(obj.eth, obj.salt, obj.token, obj.amount, obj.nft, new BabyJubjub.Point(obj.pubKey.x, obj.pubKey.y));
  }

  static decrypt({ utxoHash, memo, privKey }: { utxoHash: Field; memo: Buffer; privKey: string }): UTXO {
    let multiplier = BabyJubjub.Point.getMultiplier(privKey);
    let ephemeralPubKey = BabyJubjub.Point.decode(memo.subarray(0, 32));
    let sharedKey = ephemeralPubKey.mul(multiplier).encode();
    let data = memo.subarray(32, 81);
    let decrypted = chacha20.decrypt(sharedKey, 0, data); // prints "testing"

    let salt = Field.fromBuffer(decrypted.subarray(0, 16));
    let tokenAddress = getTokenAddress(decrypted.subarray(16, 17)[0]);
    let value = Field.fromBuffer(decrypted.subarray(17, 49));

    let myPubKey: BabyJubjub.Point = BabyJubjub.Point.fromPrivKey(privKey);
    if (tokenAddress.isZero()) {
      let etherNote = UTXO.newEtherNote({ eth: value, pubKey: myPubKey, salt });
      if (utxoHash.equal(etherNote.hash())) {
        return etherNote;
      }
    } else {
      let erc20Note = UTXO.newERC20Note({ eth: Field.from(0), tokenAddr: tokenAddress, erc20Amount: value, pubKey: myPubKey, salt });
      if (utxoHash.equal(erc20Note.hash())) {
        return erc20Note;
      }
      let nftNote = UTXO.newNFTNote({ eth: Field.from(0), tokenAddr: tokenAddress, nft: value, pubKey: myPubKey, salt });
      if (utxoHash.equal(nftNote.hash())) {
        return nftNote;
      }
    }
    return null;
  }
}
