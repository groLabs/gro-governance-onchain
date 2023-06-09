// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title Gro Protocol Voting Aggregator Interface
interface IAggregator {
    function balanceOf(address account) external view returns (uint256);

    function setVestingWeight(
        address vesting,
        uint256 lockedWeight,
        uint256 unlockedWeight
    ) external;

    function vest(
        bool vest,
        address account,
        uint256 amount
    ) external;
}
