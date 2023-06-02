// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "./Interfaces/IAggregator.sol";

contract GroGovernor is Governor, GovernorCountingSimple {
    constructor() Governor("GRO Governor") {}

    IAggregator public constant AGGREGATOR =
        IAggregator(0x156d9aaD5975Ec9Aa9E2C621F408C8469D0D6953);

    /// @notice No voting delay as we are almost using current vested voting power
    function votingDelay() public pure override returns (uint256) {
        // TODO: Double check this
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400; // 1 week
    }

    /// TODO: Double-check
    function CLOCK_MODE() public view override returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    /// TODO: Double-check
    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    /// TODO: Decide on implementation of quorum
    function quorum(
        uint256 timepoint
    ) public view virtual override returns (uint256) {
        return 0;
    }

    /// @notice Get the votes an account has for a proposal
    /// @param account The address to get votes for
    /// @param timepoint The timestamp to get votes for - not used, always returns current block
    /// @param params The parameters to pass - not used
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory params
    ) internal view override returns (uint256) {
        return AGGREGATOR.balanceOf(account);
    }
}
