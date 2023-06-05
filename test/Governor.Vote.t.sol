// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";

contract GovernorVoteTest is BaseFixture {
    uint256 internal proposalId;

    function setUp() public override {
        super.setUp();
        proposalId = spinUpTestProposal();
        utils.mineBlocks(1000);
    }

    function testVoteSimple() public {
        // Give some voting power to voter
        aggregator.setBalance(alice, governor.PROPOSAL_THRESHOLD());
        vm.prank(alice);
        // Vote
        governor.castVote(proposalId, 1);
        // Check vote
        assertTrue(governor.hasVoted(proposalId, alice));
        // Check that votes were counted properly
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governor.proposalVotes(proposalId);
        assertEq(againstVotes, 0);
        assertEq(forVotes, governor.PROPOSAL_THRESHOLD());
        assertEq(abstainVotes, 0);
    }
}
