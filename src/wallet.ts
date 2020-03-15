import { Hex } from 'web3-utils';
import { eddsa } from 'elliptic';
import 'bip39';
import { randomBytes } from 'crypto';
import Web3 from 'web3';

class Wallet {
  key: eddsa.KeyPair;
  web3: Web3;
}
