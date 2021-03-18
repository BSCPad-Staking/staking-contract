var BSCPAD = artifacts.require('BSCPAD');

module.exports = function (deployer, network) {
  if (network === 'test') return;
  deployer.then(function () {
    return;
    return deployer.deploy(BSCPAD).then(function (token) {
      console.log(`BSCPAD is deployed at ${token.address}`);
    });
  });
};
