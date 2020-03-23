import { Hex } from 'web3-utils';
import { soliditySha3, padLeft } from 'web3-utils';

export function root(hashes: Hex[]): Hex {
  if (hashes.length === 0) {
    return padLeft(0, 64);
  } else if (hashes.length === 1) {
    return hashes[0];
  }
  let parents: string[] = [];
  let numOfParentNodes = Math.ceil(hashes.length / 2);
  let hasEmptyLeaf = hashes.length % 2 === 1;
  for (let i = 0; i < numOfParentNodes; i++) {
    if (hasEmptyLeaf && i == numOfParentNodes - 1) {
      parents[i] = soliditySha3(hashes[i * 2]);
    } else {
      parents[i] = soliditySha3(hashes[i * 2], hashes[i * 2 + 1]);
    }
  }
  return root(parents);
}

export class Queue {
  buffer: Buffer;
  cursor: number;
  constructor(buffer: Buffer) {
    this.buffer = buffer;
    this.cursor = 0;
  }
  dequeue(n: number): Buffer {
    let dequeued = this.buffer.slice(this.cursor, this.cursor + n);
    this.cursor += n;
    return dequeued;
  }
}
