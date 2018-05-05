pragma solidity ^0.4.21;

import "./plcrvoting/PLCRVoting.sol";
import "./BancorFormula.sol";

contract BcPlcrVoting is PLCRVoting, BancorFormula {

  event _LogMint(uint amountMinted, uint totalCost);
  event _VoteCommited(uint indexed pollID, uint numTokens, uint commitAmount, address indexed voter);
  event _VoteRevealed(uint indexed _pollID, uint commitAmount, uint votesFor, uint votesAgainst, uint indexed choice, address indexed voter);
  event _PollCreated(uint voteQuorum, uint commitEndDate, uint revealEndDate, uint indexed pollID, uint32 reserveRatio, address indexed creator);

  function BcPlcrVoting(address _tokenAddr) PLCRVoting(_tokenAddr) public {}

  function commitVote(uint _pollID, bytes32 _secretHash, uint _numTokens, uint _prevPollID) external {
    require(commitPeriodActive(_pollID));
    require(voteTokenBalance[msg.sender] >= _numTokens);
    require(_pollID != 0);
    require(_prevPollID == 0 || dllMap[msg.sender].contains(_prevPollID));

    uint nextPollID = dllMap[msg.sender].getNext(_prevPollID);
    nextPollID = (nextPollID == _pollID) ? dllMap[msg.sender].getNext(_pollID) : nextPollID;

    uint commitAmount = bondingCurve(_numTokens, _pollID);
    require(validPosition(_prevPollID, nextPollID, msg.sender, _numTokens));
    dllMap[msg.sender].insert(_prevPollID, _pollID, nextPollID);
    bytes32 UUID = attrUUID(msg.sender, _pollID);

    store.setAttribute(UUID, "numTokens", _numTokens);
    store.setAttribute(UUID, "commitHash", uint(_secretHash));
    store.setAttribute(UUID, "commitAmount", commitAmount);

    pollMap[_pollID].didCommit[msg.sender] = true;
    emit _VoteCommited(_pollID, _numTokens, commitAmount, msg.sender);
  }

  function revealVote(uint _pollID, uint _voteOption, uint _salt) external {
    require(revealPeriodActive(_pollID));
    require(pollMap[_pollID].didCommit[msg.sender]);
    require(!pollMap[_pollID].didReveal[msg.sender]);
    require(keccak256(_voteOption, _salt) == getCommitHash(msg.sender, _pollID));

    uint commitAmount = getCommitAmount(msg.sender, _pollID);
    if(_voteOption == 1) {
      pollMap[_pollID].votesFor += commitAmount;
    } else {
      pollMap[_pollID].votesAgainst += commitAmount;
    }

    dllMap[msg.sender].remove(_pollID);
    pollMap[_pollID].didReveal[msg.sender] = true;
    emit _VoteRevealed(_pollID, commitAmount, pollMap[_pollID].votesFor, pollMap[_pollID].votesAgainst, _voteOption, msg.sender);
  }

  function bondingCurve(uint _numTokens, uint _pollID) internal returns (uint) {
    require(_numTokens > 0);
    uint BcValue = calculatePurchaseReturn(pollMap[_pollID].totalSupply, pollMap[_pollID].poolBalance, pollMap[_pollID].reserveRatio, _numTokens);
    pollMap[_pollID].totalSupply = pollMap[_pollID].totalSupply.add(BcValue);
    pollMap[_pollID].poolBalance = pollMap[_pollID].poolBalance.add(_numTokens);
    emit _LogMint(BcValue, _numTokens);
    return BcValue;
  }

  function startPoll(uint _voteQuorum, uint _commitDuration, uint _revealDuration, uint32 _reserveRatio) public returns (uint pollID) {
    pollNonce = pollNonce.add(1);
    uint commitEndDate = block.timestamp.add(_commitDuration);
    uint revealEndDate = commitEndDate.add(_revealDuration);

    pollMap[pollNonce] = Poll({
      voteQuorum: _voteQuorum,
      commitEndDate: commitEndDate,
      revealEndDate: revealEndDate,
      votesFor: 0,
      votesAgainst: 0,
      poolBalance: 0,
      totalSupply: 0,
      reserveRatio: _reserveRatio
    });
    emit _PollCreated(_voteQuorum, commitEndDate, revealEndDate, pollNonce, _reserveRatio, msg.sender);
    return pollNonce;
  }

  function getCommitAmount(address _voter, uint _pollID) view public returns (uint commitAmount) {
    return store.getAttribute(attrUUID(_voter, _pollID), "commitAmount");
  }
}