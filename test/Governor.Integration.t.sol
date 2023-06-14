// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./BaseFixture.sol";
import "../src/Interfaces/IGTranche.sol";
import "../src/Interfaces/IGVault.sol";
import "../src/Interfaces/IAggregator.sol";
import "../src/Interfaces/IBurner.sol";
import "forge-std/interfaces/IERC20.sol";

/// @title Governor Integration Tests
contract GovernorIntegrationTest is BaseFixture {
    // GSquared owner
    address public constant DAO_MSIG =
        address(0x359F4fe841f246a095a82cb26F5819E10a91fe0d);

    address public constant GRO_GTRANCHE =
        address(0x19A07afE97279cb6de1c9E73A13B7b0b63F7E67A);
    address public constant GRO_VAULT =
        address(0x1402c1cAa002354fC2C4a4cD2b4045A5b9625EF3);
    address public constant GRO_AGGREGATOR =
        address(0x156d9aaD5975Ec9Aa9E2C621F408C8469D0D6953);
    address public constant GRO_TOKEN =
        address(0x3Ec8798B81485A254928B70CDA1cf0A2BB0B74D7);
    address public constant GRO_VESTING_OWNER =
        address(0xBa5ED108abA290BBdFDD88A0F022E2357349566a);
    address public constant MAIN_VESTING_CONTRACT =
        address(0x748218256AfE0A19a88EBEB2E0C5Ce86d2178360);
    address public constant BURNER_CONTRACT =
        address(0x1F09e308bb18795f62ea7B114041E12b426b8880);

    IGTranche public gTranche;
    IGVault public gVault;
    IAggregator public groAggregator;
    IERC20 public groToken;
    IBurner public groBurner;
    GroGovernor public integrationGovernor;

    function setUp() public override {
        super.setUp();
        // Deployed mainnet addresses
        gTranche = IGTranche(GRO_GTRANCHE);
        gVault = IGVault(GRO_VAULT);
        groAggregator = IAggregator(GRO_AGGREGATOR);
        groToken = IERC20(GRO_TOKEN);
        groBurner = IBurner(BURNER_CONTRACT);

        // Transfer ownership of GTranche and GVault to Timelock
        vm.startPrank(DAO_MSIG);
        gTranche.transferOwnership(address(timelock));
        gVault.transferOwnership(address(timelock));
        vm.stopPrank();
        // Deploy new governor with real aggregator address
        integrationGovernor = new GroGovernor(
            address(groAggregator),
            timelock,
            emergencyMsig
        );
        // Grant proposer and executoooor role to governor
        vm.startPrank(emergencyMsig);
        timelock.grantRole(
            timelock.PROPOSER_ROLE(),
            address(integrationGovernor)
        );
        timelock.grantRole(
            timelock.EXECUTOR_ROLE(),
            address(integrationGovernor)
        );
        timelock.grantRole(
            timelock.CANCELLER_ROLE(),
            address(integrationGovernor)
        );
        vm.stopPrank();
    }

    function giveGroToAndVest(address _user, uint256 _amount) public {
        setStorage(
            _user,
            groToken.balanceOf.selector,
            address(groToken),
            _amount
        );
        // Approve token for burner contract
        vm.startPrank(_user);
        groToken.approve(BURNER_CONTRACT, _amount);
        // Vest
        groBurner.reVest(_amount);
        vm.stopPrank();

        vm.prank(GRO_VESTING_OWNER);
        groAggregator.setVestingWeight(MAIN_VESTING_CONTRACT, 10000, 0);
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
        vm.stopPrank();
        // Give some voting power to proposer
        giveGroToAndVest(based, integrationGovernor.proposalThreshold() * 2);
        vm.startPrank(based);
        uint256 proposalId = integrationGovernor.propose(
            targets,
            values,
            calldatas,
            "Changing utilisation threshold"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + integrationGovernor.votingDelay() + 1);
        // Give some voting power to voter
        giveGroToAndVest(alice, integrationGovernor.proposalThreshold());
        vm.prank(alice);
        // Vote
        integrationGovernor.castVote(proposalId, 1);
        // Queue:
        vm.warp(block.timestamp + integrationGovernor.votingPeriod() + 1);
        integrationGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        vm.warp(block.timestamp + 100);

        // Execute now
        vm.prank(based);
        integrationGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        // Make sure the threshold was changed
        assertEq(gTranche.utilisationThreshold(), newThreshold);
    }

    /// @dev Simple test case making sure Timelock raises error in case invalid func signature is passed
    function testInvalidSetUtilisationThresholdThroughGov() public {
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
        vm.stopPrank();
        // Give some voting power to proposer
        giveGroToAndVest(based, integrationGovernor.proposalThreshold() * 2);
        vm.startPrank(based);
        uint256 proposalId = integrationGovernor.propose(
            targets,
            values,
            calldatas,
            "Changing utilisation threshold"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + integrationGovernor.votingDelay() + 1);
        // Give some voting power to voter
        giveGroToAndVest(alice, integrationGovernor.proposalThreshold() * 2);
        vm.prank(alice);
        // Vote
        integrationGovernor.castVote(proposalId, 1);
        // Queue:
        vm.warp(block.timestamp + integrationGovernor.votingPeriod() + 1);
        integrationGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        vm.warp(block.timestamp + 100);

        // Execute now and make sure tx revert because of invalid function signature
        vm.prank(based);
        vm.expectRevert("TimelockController: underlying transaction reverted");
        integrationGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing utilisation threshold"))
        );
        // Make sure the threshold wasn't changed
        assertEq(gTranche.utilisationThreshold(), initialExpectedThreshold);
    }

    function testVestingVpDecayingOverTime() public {
        uint256 newThreshold = 20000;
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
        vm.stopPrank();
        // Give some voting power to proposer
        giveGroToAndVest(based, integrationGovernor.proposalThreshold());

        // Make sure voter has enough power now to open proposal
        assertGe(
            integrationGovernor.getVp(based),
            integrationGovernor.proposalThreshold()
        );

        // Now warp for a year and see that vesting voting power of user decreased to 0
        vm.warp(block.timestamp + 365 days);
        assertApproxEqAbs(integrationGovernor.getVp(based), 0, 9e17);
        vm.startPrank(based);
        vm.expectRevert("Governor: proposer votes below proposal threshold");
        integrationGovernor.propose(
            targets,
            values,
            calldatas,
            "Changing utilisation threshold"
        );
        vm.stopPrank();
    }

    ////////////////////////////////////////////
    //          GVault modifications          //
    ////////////////////////////////////////////
    function testSetVaultFeeThroughGov() public {
        uint256 initialExpectedFee = 0;
        uint256 newFee = 100;
        assertEq(gVault.vaultFee(), initialExpectedFee);
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(gVault);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setVaultFee(uint256)", newFee);

        vm.stopPrank();
        // Give some voting power to proposer
        giveGroToAndVest(based, integrationGovernor.proposalThreshold() * 2);
        vm.startPrank(based);
        uint256 proposalId = integrationGovernor.propose(
            targets,
            values,
            calldatas,
            "Changing vault fees"
        );
        vm.stopPrank();
        vm.warp(block.timestamp + integrationGovernor.votingDelay() + 1);
        // Give some voting power to voter
        giveGroToAndVest(alice, integrationGovernor.proposalThreshold() * 2);
        vm.prank(alice);
        // Vote
        integrationGovernor.castVote(proposalId, 1);
        // Queue:
        vm.warp(block.timestamp + integrationGovernor.votingPeriod() + 1);
        integrationGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing vault fees"))
        );
        vm.warp(block.timestamp + 100);

        // Execute now and make sure tx revert because of invalid function signature
        vm.prank(based);
        integrationGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes("Changing vault fees"))
        );
        // Make sure the fees was changed
        assertEq(gVault.vaultFee(), newFee);
    }
}
