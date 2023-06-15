// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";

contract GovernorOpsTest is BaseFixture {
    function setUp() public override {
        super.setUp();
    }

    function testClockMode() public {
        assertEq(governor.CLOCK_MODE(), "mode=timestamp");
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
        aggregator.setBalance(based, governor.proposalThreshold());

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
        aggregator.setBalance(based, governor.proposalThreshold());

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

    /// @notice Emergency msig can cancel proposals in Active state
    function testCancelProposalEmergencyMsig() public {
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
        // Check proposal state and make sure emergency msig can cancel while proposal being active
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Active));
        // Try cancel now
        vm.prank(emergencyMsig);
        governor.cancel(targets, values, calldatas, keccak256(bytes("test")));
        // Check proposal again and make sure it was canceled
        state = governor.state(proposalId);
        assertEq(uint256(state), uint256(IGovernor.ProposalState.Canceled));
    }

    /// @notice Emergency msig can cancel proposals that were already queued
    function testCancelQueuedProposalEmergencyMsig() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());
        // Calculate proposal hash for timelock controller
        bytes32 proposalTimelockHash = timelock.hashOperationBatch(
            targets,
            values,
            calldatas,
            0,
            keccak256(bytes("test"))
        );
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        // Alice votes to reach the quorum
        aggregator.setBalance(alice, governor.proposalThreshold());
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        // Mine some blocks to pass voting period
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        // Queue proposal
        vm.prank(based);
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
        // Make sure proposal is in queue now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );
        // Make sure proposal is in queue in TimelockController as well
        assertEq(timelock.isOperation(proposalTimelockHash), true);
        // Now emergency msig will cancel the proposal and make sure it's canceled in TimelockController as well
        vm.prank(emergencyMsig);
        governor.cancel(targets, values, calldatas, keccak256(bytes("test")));
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );

        assertEq(timelock.isOperation(proposalTimelockHash), false);
    }

    function testCancelProposalNoRole() public {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());

        governor.propose(targets, values, calldatas, "test");
        vm.stopPrank();
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        // Alice has no rights to cancel as she didn't create the proposal nor is she emergency msig
        vm.prank(alice);
        vm.expectRevert("GRO::cancel: not proposer or emergency msig");
        governor.cancel(targets, values, calldatas, keccak256(bytes("test")));
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
        aggregator.setBalance(based, governor.proposalThreshold());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "test"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + governor.votingDelay() + 1);
        // Make sure proposal is active now after some blocks
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active)
        );
        // Alice votes for proposal:
        aggregator.setBalance(alice, governor.proposalThreshold());
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        // Mine some blocks to pass voting period
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        // Queue proposal
        vm.prank(based);
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
        // Make sure proposal is in queue now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued)
        );

        // Mine blocks to pass timelock
        vm.warp(block.timestamp + 100);
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
        aggregator.setBalance(based, governor.proposalThreshold());

        governor.propose(targets, values, calldatas, "test");
        vm.stopPrank();
        // Try to queue proposal before proposal is successful
        vm.expectRevert("Governor: proposal not successful");
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
    }

    function testCannotQueueProposalAfterCancel() public {
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

        // Cancel proposal
        governor.cancel(targets, values, calldatas, keccak256(bytes("test")));
        vm.stopPrank();
        // Make sure proposal is canceled now
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled)
        );
        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        // Make sure it reverts when trying to queue
        vm.expectRevert("Governor: proposal not successful");
        governor.queue(targets, values, calldatas, keccak256(bytes("test")));
    }

    function testCannotExecuteBeforeQueue() public {
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
        // Alice votes for proposal:
        aggregator.setBalance(alice, governor.proposalThreshold());
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);

        // Try to execute proposal before it is queued
        vm.expectRevert("TimelockController: operation is not ready");
        governor.execute(targets, values, calldatas, keccak256(bytes("test")));
    }
}
