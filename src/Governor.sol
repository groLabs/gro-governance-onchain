// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "./Interfaces/IAggregator.sol";

contract GroGovernor is Governor, GovernorCountingSimple {
    uint256 public constant QUORUM = 1000;
    uint256 public constant PROPOSAL_THRESHOLD = 1000e18;

    IAggregator public immutable aggregator;

    constructor(address _aggregator) Governor("GRO Governor") {
        aggregator = IAggregator(_aggregator);
    }

    /// @notice No voting delay as we are almost using current vested voting power
    function votingDelay() public pure override returns (uint256) {
        // TODO: Double check this
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400; // 1 week
    }

    /// TODO: Double-check
    /// @notice Min amount of voting power needed to create a proposal
    function proposalThreshold() public pure override returns (uint256) {
        return PROPOSAL_THRESHOLD;
    }

    /// TODO: Double-check
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    /// TODO: Double-check
    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    /// TODO: Decide on implementation of quorum
    function quorum(
        uint256 /* timepoint */
    ) public view virtual override returns (uint256) {
        return QUORUM;
    }

    /// @notice Get the votes an account has for a proposal
    /// @param account The address to get votes for
    function _getVotes(
        address account,
        uint256 /* timepoint */,
        bytes memory /* params */
    ) internal view override returns (uint256) {
        return aggregator.balanceOf(account);
    }
}
