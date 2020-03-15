import * as snarkjs from 'snarkjs';
import { ZkTransaction, SNARK } from './transaction';

class ProofGenerator {
  circuit: any;
  constructor(circuit: string) {
    this.circuit = new snarkjs.Circuit(circuit);
  }

  private getCircuit(n_i: number, n_o: number) {
    return new snarkjs.Circuit();
  }
  getProof(tx: ZkTransaction): SNARK {
    let circuit = this.getCircuit(tx.inflow.length, tx.outflow.length);
    let inputs = {
      inflow: tx.inflow
    };
    let witness = circuit.calculateWitness(inputs);
    return { pi_a: [], pi_b: [[]], pi_c: [] };
  }
}
