console.log('> Compiling ERC20');
const path = require('path');
const fs = require('fs');
const solc = require('solc');
const Artifactor = require('truffle-artifactor');

let erc20Code = fs.readFileSync('./utils/TestERC20.sol', 'utf8');

let input = {
  language: 'Solidity',
  sources: {
    'TestERC20.sol': {
      content: erc20Code
    }
  },
  settings: {
    outputSelection: {
      '*': {
        '*': ['*']
      }
    }
  }
};

let output = JSON.parse(solc.compile(JSON.stringify(input)));
let sourceFile = output.contracts['TestERC20.sol'];
let contract = sourceFile['TestERC20'];

const contractsDir = path.join(__dirname, '..', 'build/generated');
let artifactor = new Artifactor(contractsDir);
fs.mkdirSync(contractsDir, { recursive: true });
(async () => {
  await artifactor.save({
    contractName: 'TestERC20',
    abi: contract.abi,
    bytecode: contract.evm.bytecode.object
  });
})();
