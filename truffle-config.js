const HDWalletProvider = require('truffle-hdwallet-provider');
require('dotenv').config();

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    bscscan: process.env.BSCSCANAPIKEY,
  },
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*',
    },
    test: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*',
    },
    bscTestnet: {
      provider: () =>
        new HDWalletProvider(
          process.env.PRIVATEKEY,
          `https://data-seed-prebsc-1-s1.binance.org:8545`
        ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
    },
  },

  compilers: {
    solc: {
      version: '0.6.12',
    },
  },
};
