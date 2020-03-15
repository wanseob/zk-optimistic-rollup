import { Hex, toBN } from 'web3-utils';

import * as circomlib from 'circomlib';
import { BabyJubjub } from './jubjub';
const poseidonHash = circomlib.poseidon.createHash(6, 8, 57, 'poseidon');

export class UTXO {
  eth: Hex;
  salt: Hex;
  token: Hex;
  amount: Hex;
  nft: Hex;
  pubKey: BabyJubjub.Point;
  constructor({ eth = '0x', salt = '0x', token = '0x', amount = '0x', nft = '0x', pubKey }) {
    this.eth = eth;
    this.salt = salt;
    this.token = token;
    this.amount = amount;
    this.nft = nft;
    this.pubKey = pubKey;
  }

  hash(): Hex {
    return poseidonHash([this.eth, this.salt, this.token, this.amount, this.nft, this.pubKey.encode()]);
  }

  nullifier(index: number): Hex {
    return poseidonHash([this.hash(), index]);
  }

  /**
  encrypt(key: eddsa.Point): Hex {
      let ephemeralSecretKey: BN = toBN(randomBytes(16).toString('hex'))
      let ephemeralPublicKey: eddsa.Point;
      let sharedKey: Hex = key.mul(ephemeralSecretKey)
      ephemeralKey.encode("hex")
 */
}
