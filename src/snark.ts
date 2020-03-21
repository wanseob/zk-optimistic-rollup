import * as snarkjs from 'snarkjs';
import { ZkTransaction, SNARK } from './transaction';

class ProofGenerator {
  circuits: { [n_i: number]: { [n_o: number]: JSON } };
  constructor() {}

  private getCircuit(n_i: number, n_o: number) {
    let circuitDef = this.circuits[n_i][n_o];
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
