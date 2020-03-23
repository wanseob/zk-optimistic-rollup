import { UTXO } from './utxo';
import { Field } from './field';
import { BabyJubjub } from './jubjub';
import { Hex } from 'web3-utils';

export interface Transaction {
  inflow: UTXO[];
  outflow: UTXO[];
  swap?: Field;
  fee: Field;
}

export interface Inflow {
  nullifier: Field;
  root: Field;
}

export interface Outflow {
  note: Field;
  outflowType: Field;
  data?: PublicData;
}

export interface PublicData {
  to: Field;
  eth: Field;
  tokenAddr: Field;
  erc20Amount: Field;
  nft: Field;
  fee: Field;
}

export class Asset {
  eth: Field;
  erc20: {
    [addr: string]: Field;
  };
  erc721: {
    [addr: string]: Field[];
  };

  static getEtherFrom(utxos: UTXO[]): Field {
    let sum = Field.from(0);
    for (let item of utxos) {
      sum = sum.add(item.eth);
    }
    return sum;
  }

  static getERC20sFrom(utxos: UTXO[]): { [addr: string]: Field } {
    let erc20 = {};
    for (let item of utxos) {
      let addr = item.tokenAddr.toHex();
      if (!item.erc20Amount.isZero() && item.nft.isZero()) {
        let prev = erc20[addr] ? erc20[addr] : Field.from(0);
        erc20[addr] = prev.add(item.erc20Amount);
      }
    }
    return erc20;
  }

  static getNFTsFrom(utxos: UTXO[]): { [addr: string]: Field[] } {
    let erc721 = {};
    for (let item of utxos) {
      let addr = item.tokenAddr.toHex();
      if (item.erc20Amount.isZero() && !item.nft.isZero()) {
        if (!erc721[addr]) {
          erc721[addr] = [];
        }
        erc721[addr].push(item.nft);
      }
    }
    return erc721;
  }

  static from(utxos: UTXO[]): Asset {
    return {
      eth: Asset.getEtherFrom(utxos),
      erc20: Asset.getERC20sFrom(utxos),
      erc721: Asset.getNFTsFrom(utxos)
    };
  }
}

export class TxBuilder {
  spendables: UTXO[];
  sendings: UTXO[];
  txFee: Field;
  swap?: Field;

  changeTo: BabyJubjub.Point;

  constructor(pubKey: BabyJubjub.Point) {
    this.spendables = [];
    this.sendings = [];
    this.changeTo = pubKey;
  }

  static from(pubKey: BabyJubjub.Point) {
    return new TxBuilder(pubKey);
  }

  fee(fee: Hex | Field): TxBuilder {
    this.txFee = Field.from(fee);
    return this;
  }

  spend(...utxos: UTXO[]): TxBuilder {
    utxos.forEach(utxo => this.spendables.push(utxo));
    return this;
  }

  /**
   * This will throw underflow Errof when it does not have enough ETH for fee
   */
  spendable(): Asset {
    let asset = Asset.from(this.spendables);
    asset.eth = asset.eth.sub(this.txFee);
    return asset;
  }

  sendEther({
    eth,
    to,
    withdrawal,
    migration
  }: {
    eth: Hex | Field;
    to: BabyJubjub.Point;
    withdrawal?: {
      to: Hex;
      fee: Hex | Field;
    };
    migration?: {
      to: Hex;
      fee: Hex | Field;
    };
  }): TxBuilder {
    if (withdrawal && migration) throw Error('You should have only one value of withdrawalTo or migrationTo');
    let utxo = UTXO.newEtherNote({ eth: eth, pubKey: to });
    if (withdrawal) {
      utxo.markAsWithdrawal(withdrawal);
    } else if (migration) {
      utxo.markAsMigration(migration);
    }
    this.sendings.push(utxo);
    return this;
  }

  sendERC20({
    tokenAddr,
    erc20Amount,
    to,
    eth,
    withdrawal,
    migration
  }: {
    tokenAddr: Hex | Field;
    erc20Amount: Hex | Field;
    to: BabyJubjub.Point;
    eth?: Hex | Field;
    withdrawal?: {
      to: Hex;
      fee: Hex | Field;
    };
    migration?: {
      to: Hex;
      fee: Hex | Field;
    };
  }): TxBuilder {
    let utxo = UTXO.newERC20Note({ eth: eth ? eth : 0, tokenAddr, erc20Amount, pubKey: to });
    if (withdrawal) {
      utxo.markAsWithdrawal(withdrawal);
    } else if (migration) {
      utxo.markAsMigration(migration);
    }
    this.sendings.push(utxo);
    return this;
  }

  sendNFT({
    tokenAddr,
    nft,
    to,
    eth,
    withdrawal,
    migration
  }: {
    tokenAddr: Hex | Field;
    nft: Hex | Field;
    to: BabyJubjub.Point;
    eth?: Hex | Field;
    withdrawal?: {
      to: Hex;
      fee: Hex | Field;
    };
    migration?: {
      to: Hex;
      fee: Hex | Field;
    };
  }): TxBuilder {
    let utxo = UTXO.newNFTNote({ eth: eth ? eth : 0, tokenAddr: tokenAddr, nft: nft, pubKey: to });
    if (withdrawal) {
      utxo.markAsWithdrawal(withdrawal);
    } else if (migration) {
      utxo.markAsMigration(migration);
    }
    this.sendings.push(utxo);
    return this;
  }

  swapForEther(amount: Field): TxBuilder {
    this.swap = UTXO.newEtherNote({
      eth: amount,
      pubKey: this.changeTo
    }).hash();
    return this;
  }

  swapForERC20({ tokenAddr, erc20Amount }: { tokenAddr: Field; erc20Amount: Field }): TxBuilder {
    this.swap = UTXO.newERC20Note({
      eth: 0,
      tokenAddr,
      erc20Amount,
      pubKey: this.changeTo
    }).hash();
    return this;
  }

  swapForNFT({ tokenAddr, nft }: { tokenAddr: Hex | Field; nft: Hex | Field }): TxBuilder {
    this.swap = UTXO.newNFTNote({
      eth: 0,
      tokenAddr: tokenAddr,
      nft,
      pubKey: this.changeTo
    }).hash();
    return this;
  }

  build(): Transaction {
    let spendables: UTXO[] = [...this.spendables];
    let spendings: UTXO[] = [];
    let sendingAmount = Asset.from(this.sendings);

    Object.keys(sendingAmount.erc20).forEach(addr => {
      let targetAmount: Field = sendingAmount.erc20[addr];
      let sameERC20UTXOs: UTXO[] = this.spendables
        .filter(utxo => utxo.tokenAddr.toHex() === addr)
        .sort((a, b) => (a.erc20Amount.greaterThan(b.erc20Amount) ? 1 : -1));
      for (let utxo of sameERC20UTXOs) {
        if (targetAmount.greaterThan(Asset.from(spendings).erc20[addr])) {
          spendings.push(...spendables.splice(spendables.indexOf(utxo), 1));
        } else {
          break;
        }
      }
      if (targetAmount.greaterThan(Asset.from(spendings).erc20[addr])) {
        throw Error(`Non enough ERC20 token ${addr} / ${targetAmount}`);
      }
    });

    Object.keys(sendingAmount.erc721).forEach(addr => {
      let sendingNFTs: Field[] = sendingAmount.erc721[addr].sort((a, b) => (a.greaterThan(b) ? 1 : -1));
      let spendingNFTNotes: UTXO[] = this.spendables.filter(utxo => {
        return utxo.tokenAddr.toHex() === addr && sendingNFTs.find(nft => nft.equal(utxo.nft)) !== undefined;
      });
      if (sendingNFTs.length != spendingNFTNotes.length) {
        throw Error('Not enough NFTs');
      }
      spendingNFTNotes.sort((a, b) => (a.nft.greaterThan(b.nft) ? 1 : -1));
      for (let i = 0; i < sendingNFTs.length; i++) {
        if (!sendingNFTs[i].equal(spendingNFTNotes[i].nft)) throw Error('Failed to find the exact NFT');
      }
      for (let utxo of spendingNFTNotes) {
        spendings.push(...spendables.splice(spendables.indexOf(utxo), 1));
      }
    });

    let requiredETH = sendingAmount.eth.add(this.txFee);
    spendables.sort((a, b) => (a.eth.greaterThan(b.eth) ? -1 : 1));
    while (requiredETH.gte(Asset.from(spendings).eth)) {
      if (spendables.length === 0) throw Error('Not enough Ether');
      spendings.push(spendables.pop());
    }

    let changes: UTXO[] = [];
    let spendingAmount = Asset.from(spendings);
    Object.keys(spendingAmount.erc20).forEach(addr => {
      let change = spendingAmount.erc20[addr].sub(sendingAmount.erc20[addr]);
      if (!change.isZero()) {
        changes.push(
          UTXO.newERC20Note({
            eth: 0,
            tokenAddr: Field.from(addr),
            erc20Amount: change,
            pubKey: this.changeTo
          })
        );
      }
    });
    let extraNFTs: { [addr: string]: Field[] } = {};
    Object.keys(spendingAmount.erc721).forEach(addr => {
      extraNFTs[addr] = spendingAmount.erc721[addr].filter(nft => {
        if (sendingAmount[addr] === undefined) return true;
        else {
          if (sendingAmount[addr].find(nft) === undefined) return true;
        }
        return false;
      });
    });
    Object.keys(extraNFTs).forEach(addr => {
      extraNFTs[addr].forEach(nft => {
        changes.push(
          UTXO.newNFTNote({
            eth: 0,
            tokenAddr: Field.from(addr),
            nft: nft,
            pubKey: this.changeTo
          })
        );
      });
    });

    let changeETH = spendingAmount.eth.sub(sendingAmount.eth).sub(this.txFee);
    if (!changeETH.isZero()) {
      changes.push(UTXO.newEtherNote({ eth: changeETH, pubKey: this.changeTo }));
    }

    let inflow = [...spendings];
    let outflow = [...this.sendings, ...changes];
    return {
      inflow,
      outflow,
      swap: this.swap,
      fee: this.txFee
    };
  }
}
