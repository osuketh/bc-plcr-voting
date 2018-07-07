const utils = require('./utils.js');

contract("bondingCurve", ([alice, bob]) => {
  it("should return BcValue collectly", async () => {
    const instance = await utils.getBcPLCRInstance();
    const options = utils.defaultOptions();
    options.actor = alice;
    const pollID = await utils.startPollAndCommitVote(options);

    const totalSupply = Number(options.startSupply);
    const poolBalance = Number(options.startPoolBalance);
    const reserveRatio = Number(options.reserveRatio) / 1e6;
    const numTokens = await utils.as(alice, instance.getNumTokens, alice, pollID)
    const amount = Number(options.numTokens);
    // const totalSupply = await instance.pollMap[pollID].totalSupply.call();
    // const poolBalance = await instance.pollMap[pollID].poolBalance.call();
    // const reserveRatio = await instance.pollMap[pollID].reserveRatio.call();

    // price calculation using bancor formula
    const price = poolBalance * ((1 + amount / totalSupply) ** (1 / (reserveRatio)) - 1);

    const estimate = await utils.as(alice, instance._getCommitAmount, alice, pollID);
    // const estimate = await utils.as(alice, instance._bondingCurve, numTokens, pollID)
    // const estimate = await instance._bondingCurve(options.numTokens, pollID);
    assert.strictEqual(price, estimate.toNumber());
  })
})