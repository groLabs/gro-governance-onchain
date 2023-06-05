pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./Utils.sol";
import "../src/Governor.sol";
import "../src/Mocks/MockVoteAggregator.sol";
import "../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract BaseFixture is Test {
    Utils internal utils;

    address payable[] internal users;
    address internal based;
    address internal alice;
    address internal bob;
    address internal joe;

    GroGovernor public governor;
    MockVoteAggregator public aggregator;
    TimelockController public timelock;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(4);
        based = users[0];
        vm.label(based, "BASED ADDRESS");
        alice = users[1];
        vm.label(alice, "Alice");
        bob = users[2];
        vm.label(bob, "Bob");
        joe = users[3];
        vm.label(joe, "Joe");
        // Deploy timelock controller:
        address[] memory proposers = new address[](1);
        proposers[0] = based;
        timelock = new TimelockController(1, proposers, proposers, based);
        // Mock aggregator
        aggregator = new MockVoteAggregator();
        // Create governor
        governor = new GroGovernor(address(aggregator), timelock);
    }

    /// @notice Spin up a test proposal with basic signature
    function spinUpTestProposal() public returns (uint256 proposalId) {
        vm.startPrank(based);
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("test()");

        // Give some voting power to proposer
        aggregator.setBalance(based, governor.PROPOSAL_THRESHOLD());

        proposalId = governor.propose(targets, values, calldatas, "test");
        vm.stopPrank();
    }
}
