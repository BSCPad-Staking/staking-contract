var BSCPAD = artifacts.require('BSCPAD');
var MockBEP20 = artifacts.require('MockBEP20');
var PadStaking = artifacts.require('PadStaking');

module.exports = function (deployer, network) {
  if (network === 'test') return;
  deployer.then(async function () {
    const devAddress = '0xBD9AeCf2c9c5F73938437bAA91dfbC5E24Bd384d';
    const bscPad = await BSCPAD.deployed();

    return deployer
      .deploy(PadStaking, bscPad.address, devAddress, devAddress, '1000', '100')
      .then(function (contract) {
        console.log(`PadStaking is deployed at ${contract.address}`);
      });
  });
};
