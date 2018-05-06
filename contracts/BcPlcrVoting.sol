pragma solidity ^0.4.23;

import "./plcrvoting/PLCRVoting.sol";
import "./BancorFormula.sol";

contract BcPlcrVoting is PLCRVoting, BancorFormula {

  event _LogMint(uint amountMinted, uint totalCost);
  event _VoteCommited(uint indexed pollID, uint numTokens, uint commitAmount, address indexed voter);
  event _VoteRevealed(uint indexed _pollID, uint commitAmount, uint votesFor, uint votesAgainst, uint indexed choice, address indexed voter);
  event _PollCreated(uint voteQuorum, uint commitEndDate, uint revealEndDate, uint pollID, uint startPoolBalance, uint startSupply, uint32 reserveRatio, address indexed creator);

  constructor(address _tokenAddr) PLCRVoting(_tokenAddr) public {}

    /**
      @notice Commits vote using hash of choice and secret salt to conceal vote until reveal
      @param _pollID Integer identifier associated with target poll
      @param _secretHash Commit keccak256 hash of voter's choice and salt (tightly packed in this order)
      @param _numTokens The number of tokens to be committed towards the target poll
      @param _prevPollID The ID of the poll that the user has voted the maximum number of tokens in which is still less than or equal to numTokens
      */
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


  /**
    @notice Reveals vote with choice and secret salt used in generating commitHash to attribute committed tokens
    @param _pollID Integer identifier associated with target poll
    @param _voteOption Vote choice used to generate commitHash for associated poll
    @param _salt Secret number used to generate commitHash for associated poll
    */
  function revealVote(uint _pollID, uint _voteOption, uint _salt) external {
    require(revealPeriodActive(_pollID));
    require(pollMap[_pollID].didCommit[msg.sender]);
    require(!pollMap[_pollID].didReveal[msg.sender]);
    require(keccak256(_voteOption, _salt) == getCommitHash(msg.sender, _pollID));

    uint commitAmount = getCommitAmount(msg.sender, _pollID);
    if(_voteOption == 1) {
      pollMap[_pollID].votesFor = pollMap[_pollID].votesFor.add(commitAmount);
    } else {
      pollMap[_pollID].votesAgainst = pollMap[_pollID].votesAgainst.add(commitAmount);
    }

    dllMap[msg.sender].remove(_pollID);
    pollMap[_pollID].didReveal[msg.sender] = true;
    emit _VoteRevealed(_pollID, commitAmount, pollMap[_pollID].votesFor, pollMap[_pollID].votesAgainst, _voteOption, msg.sender);
  }


  /**
    @dev Bonding curve based on Bancor formula
    @param _numTokens The number of tokens to be committed towards the target poll
    @param _pollID Integer identifier associated with target poll
    @return Commit amount corresponding to minted token in bonding curve
  */
  function bondingCurve(uint _numTokens, uint _pollID) internal returns (uint) {
    require(_numTokens > 0);
    uint BcValue = calculatePurchaseReturn(pollMap[_pollID].totalSupply, pollMap[_pollID].poolBalance, pollMap[_pollID].reserveRatio, _numTokens);
    pollMap[_pollID].totalSupply = pollMap[_pollID].totalSupply.add(BcValue);
    pollMap[_pollID].poolBalance = pollMap[_pollID].poolBalance.add(_numTokens);
    emit _LogMint(BcValue, _numTokens);
    return BcValue;
  }


  /**
    @dev Initiates a poll with canonical configured parameters at pollID emitted by PollCreated event
    @param _voteQuorum Type of majority (out of 100) that is necessary for poll to be successful
    @param _commitDuration Length of desired commit period in seconds
    @param _revealDuration Length of desired reveal period in seconds
    @param _startPoolBalance Start pool balance for bonding curve
    @param _startSupply Start total supply for bonding curve
    @param _reserveRatio represented in ppm, 1-1000000
    @return pollID Integer identifier associated with target poll
    */
  function startPoll(
    uint _voteQuorum,
    uint _commitDuration,
    uint _revealDuration,
    uint _startPoolBalance,
    uint _startSupply,
    uint32 _reserveRatio
  ) public returns (uint pollID)
  {
    pollNonce = pollNonce.add(1);
    uint commitEndDate = block.timestamp.add(_commitDuration);
    uint revealEndDate = commitEndDate.add(_revealDuration);

    pollMap[pollNonce] = Poll({
      voteQuorum: _voteQuorum,
      commitEndDate: commitEndDate,
      revealEndDate: revealEndDate,
      votesFor: 0,
      votesAgainst: 0,
      poolBalance: _startPoolBalance,
      totalSupply: _startSupply,
      reserveRatio: _reserveRatio
    });
    emit _PollCreated(_voteQuorum, commitEndDate, revealEndDate, pollNonce, _startPoolBalance, _startSupply, _reserveRatio, msg.sender);
    return pollNonce;
  }


  /**
    @dev Wrapper for getAttribute with attrName="commitAmount"
    @param _voter Address of user to check against
    @param _pollID Integer identifier associated with target poll
    @return Amount of tokens committed to poll depends on bonding curve in sorted poll-linked-list
    */
  function getCommitAmount(address _voter, uint _pollID) view internal returns (uint commitAmount) {
    return store.getAttribute(attrUUID(_voter, _pollID), "commitAmount");
  }
}