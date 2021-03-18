var MockBEP20 = artifacts.require('MockBEP20');

module.exports = function (deployer, network) {
  if (network === 'test') return;
  deployer.then(function () {
    return;
    return deployer
      .deploy(MockBEP20, 'BSCPad.com', 'BSCPAD', '100000')
      .then(function (token) {
        console.log(`MockBEP20 is deployed at ${token.address}`);
      });
  });
};
