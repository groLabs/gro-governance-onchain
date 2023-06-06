// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./Interfaces/IAggregator.sol";

// Use TimeLock to delay execution of proposals
contract GroGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorTimelockControl,
    AccessControl
{
    ///////// Constants /////////
    bytes32 public constant GOVERNOR_ADMIN_ROLE =
        keccak256("GOVERNOR_ADMIN_ROLE");
    uint256 public constant QUORUM = 1000;
    uint256 public constant PROPOSAL_THRESHOLD = 1000e18;

    IAggregator public immutable aggregator;

    ///////// Storage /////////
    uint256 public voteDelay = 2 days;

    ///////// Events /////////
    event VoteDelaySet(uint256 newVoteDelay, uint256 oldVoteDelay);

    constructor(
        address _aggregator,
        TimelockController _timelock
    ) Governor("GRO Governor") GovernorTimelockControl(_timelock) {
        aggregator = IAggregator(_aggregator);
        // Allow TimelockController to change parameters
        _setRoleAdmin(GOVERNOR_ADMIN_ROLE, GOVERNOR_ADMIN_ROLE);
        _setupRole(GOVERNOR_ADMIN_ROLE, address(_timelock));
    }

    /// @notice Returns the delay between when a proposal is created and when voting can start
    function votingDelay() public view override returns (uint256) {
        return voteDelay;
    }

    /// @notice Set the delay between when a proposal is created and when voting can start
    /// @param _voteDelay The new delay
    function setVotingDelay(
        uint256 _voteDelay
    ) public onlyRole(GOVERNOR_ADMIN_ROLE) {
        uint256 oldVoteDelay = voteDelay;
        voteDelay = _voteDelay;
        emit VoteDelaySet(_voteDelay, oldVoteDelay);
    }

    /// @notice Each proposal is open for voting for 5 days
    function votingPeriod() public pure override returns (uint256) {
        return 5 days;
    }

    /// TODO: Double-check
    /// @notice Min amount of voting power needed to create a proposal
    function proposalThreshold() public pure override returns (uint256) {
        return PROPOSAL_THRESHOLD;
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// TODO: Decide on implementation of quorum
    function quorum(
        uint256 /* timepoint */
    ) public view virtual override returns (uint256) {
        return QUORUM;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(Governor, GovernorTimelockControl, AccessControl)
        returns (bool)
    {
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
        // TODO: Incorporate emergency MSIG ops for cancelling
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
