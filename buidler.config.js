usePlugin('@nomiclabs/buidler-waffle');
usePlugin('solidity-coverage');
require('dotenv').config();

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

usePlugin('@nomiclabs/buidler-truffle5');

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
module.exports = {
  // This is a sample solc configuration that specifies which version of solc to use
  solc: {
    version: '0.6.12',
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },

  networks: {
    buidlerevm: {},
    development: {
      url: 'http://127.0.0.1:7545',
      port: 7545,
      network_id: '101',
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts: { mnemonic: process.env.PRIVATEKEY },
    },
    test: {
      url: 'http://127.0.0.1:7545',
      port: 7545,
      network_id: '*',
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
};
