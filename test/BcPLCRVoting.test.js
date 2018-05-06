const utils = require('./utils.js');
const BN = require('bignumber.js');

contract("Bonding-Curve-PLCRVoting", ([alice, bob, charlie]) => {

  describe("isPassed", () => {
    it("should return true if the poll passed", async () => {
      const options = utils.defaultOptions();
      options.actor = alice;
      const instance = await utils.getBcPLCRInstance();
      const pollID = await utils.startPollAndCommitVote(options);

      await utils.increaseTime(Number(options.commitPeriod) + 1);
      await utils.as(options.actor, instance.revealVote, pollID, options.vote, options.salt);
      await utils.increaseTime(Number(options.revealPeriod) + 1);
      
      const isPassed = await instance.isPassed.call(pollID);
      assert.strictEqual(isPassed, true)
    });

    it("should return false if the poll did not pass", async () => {
      const options = utils.defaultOptions();
      options.actor = alice;
      options.vote = '0';
      const instance = await utils.getBcPLCRInstance();
      const pollID = await utils.startPollAndCommitVote(options);

      await utils.increaseTime(Number(options.commitPeriod) + 1);
      await utils.as(options.actor, instance.revealVote, pollID, options.vote, options.salt);
      await utils.increaseTime(Number(options.revealPeriod) + 1);

      const isPassed = await instance.isPassed.call(pollID);
      assert.strictEqual(isPassed, false)
    })
  })

  describe("bondingCurve", () => {
    it("first voters should get more commit amount.", async () => {
      const instance = await utils.getBcPLCRInstance();

      const aliceOptions = utils.defaultOptions();
      aliceOptions.actor = alice;

      const bobOptions = utils.defaultOptions();
      bobOptions.actor = bob;

      const charlieOptions = utils.defaultOptions();
      charlieOptions.actor = charlie;

      const options = utils.defaultOptions();

      const receipt = await utils.as(alice, instance.startPoll, options.quorum, options.commitPeriod, options.revealPeriod, options.startPoolBalance, options.startSupply, options.reserveRatio);
      const pollID = utils.getPollIDFromReceipt(receipt);

      await utils.commitAs(pollID, aliceOptions);
      await utils.commitAs(pollID, bobOptions);
      await utils.commitAs(pollID, charlieOptions);

      const aliceAmount = await utils.as(alice, instance._getCommitAmount, alice, pollID);
      const bobAmount = await utils.as(bob, instance._getCommitAmount, bob, pollID);
      const charlieAmount = await utils.as(charlie, instance._getCommitAmount, charlie, pollID);

      assert.isAbove(aliceAmount.toNumber(), bobAmount.toNumber());
      assert.isAbove(bobAmount.toNumber(), charlieAmount.toNumber());
    })
  })
})