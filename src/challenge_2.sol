// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Lottery is Ownable, ReentrancyGuard {
    struct Player {
        uint256 amountWagered;
        address addr;
    }

    Player[] public players;
    uint256 public totalWagered;
    uint256 public lotteryEndTime;
    bool public lotteryOpen;
    mapping(address => uint256) public entriesPerAddress;

    event LotteryEntry(address player, uint256 amount);
    event LotteryWinner(address winner, uint256 amount);

    constructor(address initialOwner, uint256 _duration) Ownable(initialOwner) {
        lotteryEndTime = block.timestamp + _duration;
        lotteryOpen = true;
    }

    function enterLottery() external payable nonReentrant {
        require(lotteryOpen, "Lottery is not open.");
        require(msg.value > 0.01 ether, "Minimum wager is 0.01 ETH.");
        require(block.timestamp < lotteryEndTime, "Lottery has ended.");

        players.push(Player(msg.value, msg.sender));
        totalWagered += msg.value;
        entriesPerAddress[msg.sender] += 1; // Track entries per address
        emit LotteryEntry(msg.sender, msg.value);
    }

    function chooseWinner() external onlyOwner {
        require(block.timestamp >= lotteryEndTime, "Lottery is still running.");
        require(lotteryOpen, "Lottery is not open.");

        uint256 winnerIndex = pseudoRandom() % totalWagered;
        uint256 runningTotal = 0;
        address winner;

        for (uint256 i = 0; i < players.length; i++) {
            runningTotal += players[i].amountWagered;
            if (runningTotal >= winnerIndex) {
                winner = players[i].addr;
                break;
            }
        }

        payable(winner).transfer(address(this).balance);
        emit LotteryWinner(winner, address(this).balance);

        // Reset for next lottery
        delete players;
        totalWagered = 0;
        lotteryEndTime = block.timestamp + 1 days;
        lotteryOpen = true;
    }

    // NOTE - although this psuedo randomness is potenitally manipulable,
    // assume it is secure for the purpose of this challenge.
    // Answers citing this function are not correct.
    function pseudoRandom() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, address(this), totalWagered)));
    }

    function distributeRewards(address[] calldata rewardAddresses) external onlyOwner {
        for (uint256 i = 0; i < rewardAddresses.length; i++) {
            (bool success,) = rewardAddresses[i].call{value: 1 ether}("");
            require(success, "Failed to send reward");
        }
    }

    function closeLottery() external onlyOwner {
        require(lotteryOpen, "Lottery is already closed.");
        lotteryOpen = false;
    }

    function openLottery(uint256 _duration) external onlyOwner {
        require(!lotteryOpen, "Lottery is already open.");
        lotteryEndTime = block.timestamp + _duration;
        lotteryOpen = true;
    }
}