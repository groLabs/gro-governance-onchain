// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";

contract GovernorOpsTest is BaseFixture {
    function setUp() public override {
        super.setUp();
    }

    //////////////////////////////////////////////////
    //         Test create/cancel operations        //
    //////////////////////////////////////////////////
    function testCreateProposal() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.PROPOSAL_THRESHOLD());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();

        assertGt(proposalId, 0);
        // Check that proposal was created
        assertGt(governor.proposalSnapshot(proposalId), 0);

        // Check proposal state
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Pending)); // Pending
    }

    function testCreateAndCancelProposal() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.PROPOSAL_THRESHOLD());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();
        // Check proposal state
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Pending));

        // Try cancel now
        vm.startPrank(based);
        governor.cancel(targets, values, calldatas, keccak256(bytes("test")));

        // Check proposal again and make sure it was canceled
        state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Canceled));
    }

    /// @notice Testing revert when proposer creating proposal without enough voting power
    function testCreateProposalBelowThreshold() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        vm.expectRevert("Governor: proposer votes below proposal threshold");
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();

        assertEq(proposalId, 0);
        // Check that proposal was not created
        assertEq(governor.proposalSnapshot(proposalId), 0);
    }

    //////////////////////////////////////////////////
    //         Test queue/execute                   //
    //////////////////////////////////////////////////

    /// @notice Simple case of proposal creation, vote passing quorum and then queueing and executing
    function testQueueAndExecProposal() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.PROPOSAL_THRESHOLD());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();
        utils.mineBlocks(10);
        // Make sure proposal is active now after some blocks
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active)
        );
        // Alice votes for proposal:
        aggregator.setBalance(alice, governor.PROPOSAL_THRESHOLD());
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        // Mine some blocks to pass voting period
        utils.mineBlocks(governor.votingPeriod() + 1);
        // Queue proposal
        vm.prank(based);
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
        // Make sure proposal is in queue now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );

        // Mine blocks to pass timelock
        vm.warp(100);
        // Execute proposal
        vm.prank(based);
        governor.execute(targets, values, calldatas, keccak256(bytes("test")));
        // Make sure proposal is executed now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed)
        );
    }

    function testCannotQueueProposal() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.PROPOSAL_THRESHOLD());

        governor.propose(targets, values, calldatas, "test");
        vm.stopPrank();
        // Try to queue proposal before proposal is successful
        vm.expectRevert("Governor: proposal not successful");
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
    }
}
