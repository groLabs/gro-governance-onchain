// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Governor.sol";
import "./BaseFixture.sol";

contract GovernorOpsTest is BaseFixture {
    function setUp() public override {
        super.setUp();
    }

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
}
