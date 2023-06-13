// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";
import "../src/Interfaces/IGTranche.sol";

/// @title Governor Integration Tests
contract GovernorIntegrationTest is BaseFixture {
    // GSquared owner
    address public constant DAO_MSIG =
        address(0x359F4fe841f246a095a82cb26F5819E10a91fe0d);

    address public constant GRO_GTRANCHE = address(0x19A07afE97279cb6de1c9E73A13B7b0b63F7E67A);

    IGTranche public gTranche;

    function setUp() public override {
        super.setUp();
        gTranche = IGTranche(GRO_GTRANCHE);
        vm.prank(DAO_MSIG);
        gTranche.transferOwnership(address(timelock));
    }

    ////////////////////////////////////////////
    //          GTranche modifications        //
    ////////////////////////////////////////////
    function testSetUtilisationThresholdThroughGov() public {
        uint256 initialExpectedThreshold = 10000;
        uint256 newThreshold = 20000;
        assertEq(gTranche.utilisationThreshold(), initialExpectedThreshold);
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(gTranche);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "setUtilisationThreshold(uint256)",
            newThreshold
        );

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Changing utilisation threshold"
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
            keccak256(bytes("Changing utilisation threshold"))
        );
        vm.warp(block.timestamp + 100);

        // Execute now
        vm.prank(based);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        // Make sure the threshold was changed
        assertEq(gTranche.utilisationThreshold(), newThreshold);
    }

    /// @dev Simple test case making sure Timelock raises error in case invalid func signature is passed
    function testSetUtilisationThresholdThroughGovInvalid() public {
        uint256 initialExpectedThreshold = 10000;
        uint256 newThreshold = 20000;
        assertEq(gTranche.utilisationThreshold(), initialExpectedThreshold);
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(gTranche);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        // Make calldata invalid
        calldatas[0] = abi.encodeWithSignature(
            "setUtilisation(uint256)",
            newThreshold
        );

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.proposalThreshold());

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Changing utilisation threshold"
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
            keccak256(bytes("Changing utilisation threshold"))
        );
        vm.warp(block.timestamp + 100);

        // Execute now and make sure tx revert because of invalid function signature
        vm.prank(based);
        vm.expectRevert("TimelockController: underlying transaction reverted");
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        // Make sure the threshold was changed
        assertEq(gTranche.utilisationThreshold(), initialExpectedThreshold);
    }

}
