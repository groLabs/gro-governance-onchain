// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";

/// @title Governor
/// @notice This contract is used to test setting of internal configuration of the Governor contract
contract GovernorInternalSettingTest is BaseFixture {
    function setUp() public override {
        super.setUp();
    }

    function testVoteSimple() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        // Give some voting power to voter
        aggregator.setBalance(alice, governor.proposalThreshold());
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
        assertEq(forVotes, governor.proposalThreshold());
        assertEq(abstainVotes, 0);
    }

    function testRevertOnSettingConfigNotInACL() public {
        vm.prank(alice);
        vm.expectRevert();
        governor.setVotingDelay(3 days);

        vm.prank(based);
        vm.expectRevert();
        governor.setVotingDelay(3 days);
    }

    function testVoteForSettingVotingDelay() public {
        // Make sure voting delay is 2 days
        assertEq(governor.votingDelay(), 2 days);
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "setVotingDelay(uint256)",
            3 days
        );

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Changing voting delay"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        // Give some voting power to voter
        aggregator.setBalance(alice, governor.proposalThreshold());
        vm.prank(alice);
        // Vote
        governor.castVote(proposalId, 1);
        // Queue:
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing voting delay"))
        );
        vm.warp(block.timestamp + 100);
        // Execute now
        vm.prank(based);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing voting delay"))
        );
        // Make sure proposal is executed now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
        // Make sure voting delay is 3 days now
        assertEq(governor.votingDelay(), 3 days);
    }
}
