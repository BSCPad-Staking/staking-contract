var BSCPAD = artifacts.require('BSCPAD');

module.exports = function (deployer, network) {
  if (network === 'test') return;
  deployer.then(function () {
    // return;
    return deployer.deploy(BSCPAD).then(async function (token) {
      await token.initialize('10000000000000000000000');
      console.log(`BSCPAD is deployed at ${token.address}`);
    });
  });
};
