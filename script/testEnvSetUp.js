const fs = require('fs');
const path = require('path');
const snark = require('snarkjs');

const circuitDir = path.resolve(path.dirname(__filename), '../circuits/impls');
const circuits = fs.readdirSync(circuitDir);
const circuitDefs = {};
for (let circuit of circuits) {
  let circuitPath = path.resolve(circuitDir, circuit);
  circuitDefs[circuit] = JSON.parse(fs.readFileSync(circuitPath));
}
