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

    bytes32 public constant EMERGENCY_MSIG_ROLE =
        keccak256("EMERGENCY_MSIG_ROLE");

    ///////// Storage /////////
    uint256 public votePeriod = 5 days;
    uint256 public voteDelay = 2 days;
    uint256 public threshold = 1000e18;
    IAggregator public aggregator;
    uint256 public quorumVotes = 1000;

    ///////// Events /////////
    event VoteDelaySet(uint256 newVoteDelay, uint256 oldVoteDelay);
    event AggregatorSet(address newAggregator, address oldAggregator);
    event ProposalThresholdSet(
        uint256 newProposalThreshold,
        uint256 oldProposalThreshold
    );
    event QuorumSet(uint256 newQuorum, uint256 oldQuorum);
    event VotePeriodSet(uint256 newVotePeriod, uint256 oldVotePeriod);

    constructor(
        address _aggregator,
        TimelockController _timelock,
        address _emergencyMsig
    ) Governor("GRO Governor") GovernorTimelockControl(_timelock) {
        aggregator = IAggregator(_aggregator);
        // Allow TimelockController to change parameters
        _setRoleAdmin(GOVERNOR_ADMIN_ROLE, GOVERNOR_ADMIN_ROLE);
        _grantRole(GOVERNOR_ADMIN_ROLE, address(_timelock));
        // Allow emergency multisig to cancel proposals
        _grantRole(EMERGENCY_MSIG_ROLE, _emergencyMsig);
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

    /// @notice Set address of aggregator contract
    /// @param _aggregator The new aggregator
    function setAggregator(
        address _aggregator
    ) public onlyRole(GOVERNOR_ADMIN_ROLE) {
        address oldAggregator = address(aggregator);
        aggregator = IAggregator(_aggregator);
        emit AggregatorSet(_aggregator, oldAggregator);
    }

    /// @notice Set quorum for proposals
    /// @param _quorum The new quorum
    function setQuorum(uint256 _quorum) public onlyRole(GOVERNOR_ADMIN_ROLE) {
        uint256 oldQuorum = quorumVotes;
        quorumVotes = _quorum;
        emit QuorumSet(_quorum, oldQuorum);
    }

    /// @notice Each proposal is open for voting for 5 days
    function votingPeriod() public view override returns (uint256) {
        return votePeriod;
    }

    /// @notice Set voting period for proposals
    /// @param _votePeriod The new voting period
    function setVotingPeriod(
        uint256 _votePeriod
    ) public onlyRole(GOVERNOR_ADMIN_ROLE) {
        uint256 oldVotePeriod = votePeriod;
        votePeriod = _votePeriod;
        emit VotePeriodSet(_votePeriod, oldVotePeriod);
    }

    /// @notice Min amount of voting power needed to create a proposal
    function proposalThreshold() public view override returns (uint256) {
        return threshold;
    }

    /// @notice Set min amount of voting power needed to create a proposal
    /// @param _proposalThreshold The new proposal threshold
    function setProposalThreshold(
        uint256 _proposalThreshold
    ) public onlyRole(GOVERNOR_ADMIN_ROLE) {
        uint256 oldProposalThreshold = threshold;
        threshold = _proposalThreshold;
        emit ProposalThresholdSet(_proposalThreshold, oldProposalThreshold);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function quorum(
        uint256 /* timepoint */
    ) public view virtual override returns (uint256) {
        return quorumVotes;
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

    /// @notice Get the voting power of an account
    function getVp(address account) public view returns (uint256) {
        return aggregator.balanceOf(account);
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

    /// @notice Proposal can be cancelled by proposer or emergency msig
    /// @param targets The ordered list of target addresses for calls to be made
    /// @param values The ordered list of values (i.e. msg.value)
    /// @param calldatas The ordered list of calldata to be passed to each call
    /// @param descriptionHash The hash of the description of the proposal
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public override(Governor, IGovernor) returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );
        require(
            _msgSender() == proposalProposer(proposalId) ||
                hasRole(EMERGENCY_MSIG_ROLE, _msgSender()),
            "GRO::cancel: not proposer or emergency msig"
        );
        return _cancel(targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorTimelockControl, Governor) returns (uint256) {
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
