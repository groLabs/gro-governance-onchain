pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./Utils.sol";
import "../src/GroGovernor.sol";
import "../src/Mocks/MockVoteAggregator.sol";
import "../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract BaseFixture is Test {
    Utils internal utils;

    address payable[] internal users;
    address internal based;
    address internal alice;
    address internal bob;
    address internal joe;
    address internal emergencyMsig;

    GroGovernor public governor;
    MockVoteAggregator public aggregator;
    TimelockController public timelock;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(5);
        based = users[0];
        vm.label(based, "BASED ADDRESS");
        alice = users[1];
        vm.label(alice, "Alice");
        bob = users[2];
        vm.label(bob, "Bob");
        joe = users[3];
        vm.label(joe, "Joe");
        emergencyMsig = users[4];
        vm.label(emergencyMsig, "Emergency MSIG");
        // Deploy timelock controller:
        address[] memory proposers = new address[](1);
        proposers[0] = based;
        timelock = new TimelockController(1, proposers, proposers, based);
        // Mock aggregator
        aggregator = new MockVoteAggregator();
        // Create governor
        governor = new GroGovernor(
            address(aggregator),
            timelock,
            emergencyMsig
        );

        // Grant proposer and executoooor role to governor
        vm.startPrank(based);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        vm.stopPrank();
    }
}
