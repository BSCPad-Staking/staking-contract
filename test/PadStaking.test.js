const { expectRevert, time } = require('@openzeppelin/test-helpers');
const PadStaking = artifacts.require('PadStaking');
const MockBEP20 = artifacts.require('libs/MockBEP20');
const BSCPAD = artifacts.require('BSCPAD');

contract('PadStaking', ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
    // this.pad = await MockBEP20.new('BSCPad.com', 'BSCPAD', '100000', {
    //   from: minter,
    // });

    this.pad = await BSCPAD.new({ from: minter });
    this.pad.initialize(100000, { from: minter });

    this.chef = await PadStaking.new(
      this.pad.address,
      dev,
      minter,
      '1000',
      '100',
      { from: minter }
    );
  });

  it('staking/unstaking', async () => {
    await time.advanceBlockTo('170');
    await this.pad.transfer(alice, '250', { from: minter });
    await this.pad.approve(this.chef.address, '1000', { from: alice });

    await this.chef.enterStaking('240', { from: alice });
    assert.equal(
      (await this.pad.balanceOf(this.chef.address)).toString(),
      '240'
    );
    assert.equal((await this.pad.balanceOf(alice)).toString(), '10');
    assert.equal((await this.chef.rewardOf(alice)).toString(), '0');

    await this.chef.enterStaking('10', { from: alice }); //4
    assert.equal(
      (await this.pad.balanceOf(this.chef.address)).toString(),
      '250'
    );
    assert.equal((await this.pad.balanceOf(alice)).toString(), '0');
    assert.equal((await this.chef.rewardOf(alice)).toString(), '999');

    await this.chef.leaveStaking(250);
    assert.equal((await this.pad.balanceOf(this.chef.address)).toString(), '0');
    assert.equal((await this.pad.balanceOf(alice)).toString(), '250');
    assert.equal((await this.chef.rewardOf(alice)).toString(), '2249');

    await this.chef.enterStaking('240', { from: alice }); //4
    assert.equal(
      (await this.pad.balanceOf(this.chef.address)).toString(),
      '240'
    );
    assert.equal((await this.pad.balanceOf(alice)).toString(), '10');
    assert.equal((await this.chef.rewardOf(alice)).toString(), '2249');

    await this.chef.leaveStaking('40', { from: alice }); //4
    assert.equal(
      (await this.pad.balanceOf(this.chef.address)).toString(),
      '200'
    );
    assert.equal((await this.pad.balanceOf(alice)).toString(), '50');
    assert.equal((await this.chef.rewardOf(alice)).toString(), '3289');
  });
});
