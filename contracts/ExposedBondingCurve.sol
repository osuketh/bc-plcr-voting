pragma solidity ^0.4.23;

import "./BcPlcrVoting.sol";

contract ExposedBondingCurve is BcPlcrVoting {
  constructor(address _tokenAddr) BcPlcrVoting(_tokenAddr) public {}

    function _bondingCurve(uint _numTokens, uint _pollID) public returns (uint) {
      require(_numTokens > 0);
      uint BcValue = calculatePurchaseReturn(pollMap[_pollID].totalSupply, pollMap[_pollID].poolBalance, pollMap[_pollID].reserveRatio, _numTokens);
      pollMap[_pollID].totalSupply = pollMap[_pollID].totalSupply.add(BcValue);
      pollMap[_pollID].poolBalance = pollMap[_pollID].poolBalance.add(_numTokens);
      emit _LogMint(BcValue, _numTokens);
      return BcValue;
    }

    function _getCommitAmount(address _voter, uint _pollID) view public returns (uint commitAmount) {
      return store.getAttribute(attrUUID(_voter, _pollID), "commitAmount");
    }    
}