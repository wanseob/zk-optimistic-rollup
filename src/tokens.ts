import { hexToNumber, padLeft, toChecksumAddress } from 'web3-utils';
import { Field } from './field';

export namespace TokenAddress {
  export const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f';
  export const CRYPTO_KITTIES = '0x06012c8cf97bead5deae237070f9587f8e7a266d';
}

const tokenIdMap: Object = {};
tokenIdMap['0x0'] = 0;
tokenIdMap[TokenAddress.DAI] = 1;
tokenIdMap[TokenAddress.CRYPTO_KITTIES] = 2;

export function getTokenId(addr: Field): number {
  let hexAddr = padLeft('0x' + addr.val.toString(16), 40);
  let checkSumAddress = toChecksumAddress(hexAddr);
  let id = tokenIdMap[checkSumAddress];
  if (id === undefined) {
    id = 0;
  }
  if (id >= 256) throw Error('Only support maximum 255 number of tokens');
  return id;
}

export function getTokenAddress(id: number): Field {
  if (id >= 256) throw Error('Only support maximum 255 number of tokens');
  let key = id;
  if (typeof id === 'string') {
    key = hexToNumber(id);
  }
  for (let obj in tokenIdMap) {
    if (tokenIdMap[obj] === key) return Field.from(obj);
  }
  return null;
}
