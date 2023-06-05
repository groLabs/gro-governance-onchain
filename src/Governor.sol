// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./Interfaces/IAggregator.sol";

// Use TimeLock to delay execution of proposals
contract GroGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorTimelockControl
{
    uint256 public constant QUORUM = 1000;
    uint256 public constant PROPOSAL_THRESHOLD = 1000e18;

    IAggregator public immutable aggregator;

    constructor(
        address _aggregator,
        TimelockController _timelock
    ) Governor("GRO Governor") GovernorTimelockControl(_timelock) {
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
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

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.cancel(targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
}
