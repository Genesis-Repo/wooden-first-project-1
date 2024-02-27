// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    // Variables
    address[] public winners;
    uint256 public prizePool;
    uint256 public charityPool;
    mapping(address => bool) public isParticipant;
    mapping(address => bool) public hasClaimedPrize;

    // Events
    event TicketPurchased(address indexed buyer);
    event WinnersSelected(address[] winners);
    event PrizeClaimed(address winner, uint256 amount);
    event CharityWinnerSelected(address winner, uint256 amount);

    // Modifiers
    modifier notOwner() {
        require(msg.sender != owner(), "Owner cannot participate");
        _;
    }

    // Functions
    function purchaseTicket() external payable notOwner {
        // Ensure the contract has received some ether
        require(msg.value >= 0.01 ether, "Minimum ticket price is 0.01 ether");

        // Each ticket cost 0.01 ether
        uint256 ticketsBought = msg.value / 0.01 ether;

        // Update prize and charity pool balances
        prizePool += (msg.value * 6) / 10;
        charityPool += (msg.value * 4) / 10;

        // Mark buyer as a participant
        isParticipant[msg.sender] = true;

        emit TicketPurchased(msg.sender);
    }

    function selectWinners(uint256 numberOfWinners) external onlyOwner {
        require(address(this).balance >= prizePool, "Contract has insufficient balance");
        require(numberOfWinners > 0, "Number of winners must be greater than zero");

        address[] memory selectedWinners = new address[](numberOfWinners);

        for (uint256 i = 0; i < numberOfWinners; i++) {
            address winner = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.number - 1, i))) % (2**160)));
            require(isParticipant[winner], "Winner is not a participant");
            selectedWinners[i] = winner;
            hasClaimedPrize[winner] = false;
        }

        winners = selectedWinners;

        emit WinnersSelected(selectedWinners);
    }

    function claimPrize() external {
        require(isParticipant[msg.sender], "Sender is not a participant");

        uint256 amountWon = prizePool / winners.length;

        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i] == msg.sender && !hasClaimedPrize[msg.sender]) {
                (bool success, ) = payable(msg.sender).call{value: amountWon}("");
                require(success, "Transfer failed");
                hasClaimedPrize[msg.sender] = true;

                emit PrizeClaimed(msg.sender, amountWon);
            }
        }

        prizePool = 0;
    }

    function selectCharityWinner(address charityWinner) external onlyOwner {
        require(charityPool > 0, "Charity pool is empty");
        require(isParticipant[charityWinner], "Charity winner must be a participant");

        // Transfer the charity pool to the selected winner
        (bool success, ) = payable(charityWinner).call{value: charityPool}("");
        require(success, "Transfer failed");

        charityPool = 0;

        emit CharityWinnerSelected(charityWinner, charityPool);
    }

    // Fallback function to accept ether
    receive() external payable {
        // Only owner can send ether directly to the contract
        require(msg.sender == owner(), "Only owner can send ether");
    }

    // Withdraw function to safely withdraw funds
    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;

        (bool success, ) = payable(owner()).call{value: contractBalance}("");
        require(success, "Withdrawal failed");
    }
}