const ExposedBondingCurve = artifacts.require("ExposedBondingCurve");
const abi = require('ethereumjs-abi');

const utils = {
  as: (actor, fn, ...args) => {
    function detectSendObject(potentialSendObj) {
      function hasOwnProperty(obj, prop) {
        const proto = obj.constructor.prototype;
        return (prop in obj) &&
       (!(prop in proto) || proto[prop] !== obj[prop]);
      }

      if (typeof potentialSendObj === 'object') {
        if (hasOwnProperty(potentialSendObj, 'from') ||
           hasOwnProperty(potentialSendObj, 'to') ||
           hasOwnProperty(potentialSendObj, 'gas') ||
           hasOwnProperty(potentialSendObj, 'gasPrice') ||
           hasOwnProperty(potentialSendObj, 'value')
        ) {
          throw new Error('It is unsafe to use "as" with custom send objects');
        }
      }
    }
    detectSendObject(args[args.length - 1]);
    const sendObject = { from: actor };
    return fn(...args, sendObject);
  },
  createVoteHash: (vote, salt) => {
    const hash = `0x${abi.soliditySHA3(['uint', 'uint'], [vote, salt]).toString('hex')}`;
    return hash;
  },
  getPollIDFromReceipt: receipt => receipt.logs[0].args.pollID,
  getBcPLCRInstance: () => ExposedBondingCurve.deployed(),
  validOptions: (options) => {
    if (
      typeof options.actor !== 'string' ||
      typeof options.votingRights !== 'string' ||
      typeof options.quorum !== 'string' ||
      typeof options.revealPeriod !== 'string' ||
      typeof options.commitPeriod !== 'string' ||
      typeof options.vote !== 'string' ||
      typeof options.salt !== 'string' ||
      typeof options.numTokens !== 'string' ||
      typeof options.startSupply !== 'string' ||
      typeof options.startPoolBalance !== 'string' ||
      typeof options.reserveRatio !== 'string'
    ) {
      return false;
    }

    return true;
  },
  startPollAndCommitVote: async (options) => {
    if (!utils.validOptions(options)) {
      throw new Error('Please specify all options to startPollAndCommitVote as strings');
    }
    const instance = await utils.getBcPLCRInstance();
    await utils.as(options.actor, instance.requestVotingRights, options.votingRights);

    const receipt = await utils.as(options.actor, instance.startPoll, options.quorum, options.commitPeriod, options.revealPeriod, options.startPoolBalance, options.startSupply, options.reserveRatio);
    const pollID = utils.getPollIDFromReceipt(receipt);
    const secretHash = utils.createVoteHash(options.vote, options.salt);

    let prevPollID;
    if (typeof options.prevPollID === "undefined") {
      prevPollID = await instance.getInsertPointForNumTokens.call(options.actor, options.numTokens, pollID);
    } else if (typeof options.prevPollID === 'string') {
      prevPollID = options.prevPollID;
    } else {
      throw new Error('Please specify all options to startPollAndCommitVote as strings');
    }
    await utils.as(options.actor, instance.commitVote, pollID, secretHash, options.numTokens, prevPollID);
    return pollID;
  },
  commitAs: async (pollID, options) => {
    if (!utils.validOptions(options)) {
      throw new Error('Please specify all options to startPollAndCommitVote as strings.');
    }
    const instance = await utils.getBcPLCRInstance();
    await utils.as(options.actor, instance.requestVotingRights, options.votingRights);
    const secretHash = utils.createVoteHash(options.vote, options.salt);

    let prevPollID;
    if (typeof options.prevPollID === 'undefined') {
      prevPollID = await instance.getInsertPointForNumTokens.call(options.actor, options.numTokens, pollID);
    } else if (typeof options.prevPollID === 'string') {
      prevPollID = options.prevPollID;
    } else {
      throw new Error('Please specify all options to commitAs as strings.');
    }

    await utils.as(options.actor, instance.commitVote, pollID, secretHash, options.numTokens, prevPollID);
  },
  increaseTime: (seconds) => {
    if ((typeof seconds) !== 'number') {
      throw new Error('Arguments to increaseTime must be of type number');
    }
    const id = Date.now();

    return new Promise((resolve, reject) => {
      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [seconds],
        id: id,
      }, err1 => {
        if (err1) return reject(err1);

        web3.currentProvider.sendAsync({
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: id + 1,
        }, (err2, res) => {
          return err2 ? reject(err2) : resolve(res);
        });
      });
    });
  },
  defaultOptions: () => ({
    votingRights: '50',
    quorum: '50',
    commitPeriod: '100',
    revealPeriod: '100',
    vote: '1',
    salt: '420',
    numTokens: '20',
    startSupply: '10',
    startPoolBalance: '1',
    reserveRatio: `${Math.floor((Math.round(1 / 3 * 1000000) / 1000000) * 1000000)}`,
  })
};

module.exports = utils;