// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Interfaces/IAggregator.sol";

contract MockVoteAggregator is IAggregator {
    mapping (address => uint256) public balances;

    function setBalance(address account, uint256 balance) external {
        balances[account] = balance;
    }

    /// @dev Imitate the behavior of the aggregator
    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    /// @dev don't use this function it's a stub
    function setVestingWeight(
        address vesting,
        uint256 lockedWeight,
        uint256 unlockedWeight
    ) external {
        balances[vesting] = lockedWeight + unlockedWeight;
    }

    /// @dev don't use this function it's a stub
    function vest(
        bool vest,
        address account,
        uint256 amount
    ) external {
        if (vest) {
            balances[account] += amount;
        } else {
            balances[account] -= amount;
        }
    }
}
