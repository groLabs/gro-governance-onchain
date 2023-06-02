pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "./Utils.sol";
import "../src/Governor.sol";
import "../src/Mocks/MockVoteAggregator.sol";

contract BaseFixture is Test {
    Utils internal utils;

    address payable[] internal users;
    address internal based;
    address internal alice;
    address internal bob;
    address internal joe;

    GroGovernor public governor;
    MockVoteAggregator public aggregator;

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
        // Mock aggregator
        aggregator = new MockVoteAggregator();
        // Create governor
        governor = new GroGovernor(address(aggregator));
    }
}
