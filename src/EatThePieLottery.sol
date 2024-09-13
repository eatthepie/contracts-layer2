// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin contracts for security best practices
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// Assuming you have the VDF Pietrzak contract
import "./VDFPietrzak.sol";

contract EatThePieLottery is Ownable, ReentrancyGuard, ERC721URIStorage {
    // Enums
    enum Difficulty { Easy, Medium, Hard }

    // Structs
    struct Player {
        uint256 consecutiveGamesPlayed;
        uint256 lastGamePlayed;
        mapping(uint256 => bytes32[]) goldTickets;
        mapping(uint256 => bytes32[]) SilverTickets; 
        mapping(uint256 => bytes32[]) BronzeTickets;
    }

    // Constants
    /* prize pool distribution (percentages) */
    uint256 public constant GOLD_PERCENTAGE = 6000;
    uint256 public constant SILVER_PLACE_PERCENTAGE = 2500;
    uint256 public constant BRONZE_PLACE_PERCENTAGE = 1000;
    uint256 public constant LOYALTY_PERCENTAGE = 400;
    uint256 public constant FEE_PERCENTAGE = 100;
    /* lottery ball numbers (max allowed numbers) */
    uint256 public constant EASY_MAX = 50;
    uint256 public constant EASY_ETHERBALL_MAX = 5;
    uint256 public constant MEDIUM_MAX = 100;
    uint256 public constant MEDIUM_ETHERBALL_MAX = 10;
    uint256 public constant HARD_MAX = 150;
    uint256 public constant HARD_ETHERBALL_MAX = 15;
    /* draw threshold */
    uint256 public constant DRAW_MIN_PRIZE_POOL = 500 ether;
    uint256 public constant DRAW_INTERVAL = 1 weeks;
    uint256 public constant DRAW_EPOCH_OFFSET = 4; // delay for 4 epochs
    uint256 public constant DRAW_BLOCK_OFFSET = 2; // delay for 2 blocks in epoch

    // State Variables
    uint256 public ticketPrice;
    uint256 public currentGameNumber;
    uint256 public lastDrawTime;
    /* check if game difficulty needs to be adjusted */
    uint256 public consecutiveJackpots;
    uint256 public consecutiveNoJackpots;
    /* new game difficulty */
    /* anyone can call changeDifficulty() */
    Difficulty public newDifficulty;
    uint256 public newDifficultyGame;
    /* new ticket price */
    /* only admin capability - can change ticket price if needed. will have a 4 game buffer */
    uint256 public newTicketPrice;
    uint256 public newTicketPriceGameNumber;

    // game state
    mapping(uint256 => uint256) public gamePrizePool;
    mapping(uint256 => Difficulty) public gameDifficulty;
    mapping(uint256 => uint256[4][]) public gameWinningNumbers;
    mapping(uint256 => address player) public gameWinnerLoyaltyPrize;
    mapping(uint256 -> uint256[4]) public gamePayouts; // gold, silver, bronze, loyalty
    // tickets
    mapping(uint256 => mapping(bytes32 => address[])) public goldTickets;
    mapping(uint256 => mapping(bytes32 => address[])) public silverTickets;
    mapping(uint256 => mapping(bytes32 => address[])) public bronzeTickets;
    // generate lottery numbers - using prevRandao & VDF
    mapping(uint256 => bool) public gameDrawInitiated;
    mapping(uint256 => bytes32) public gameRandao;
    mapping(uint256 => uint256) public gameRandaoBlockMin;
    mapping(uint256 => bool) public gameVDFValid;
    // game results
    mapping(uint256 => bool) public gameDrawCompleted;
    mapping(address => Player) public playerInfo;

    // VDF Pietrzak contract instance
    VDFPietrzak public vdfContract;

    // Events
    event TicketPurchased(address indexed player, uint256 gameNumber, uint256[3] numbers, uint256 etherball);
    event DrawInitiated(uint256 gameNumber);
    event RandaoSet(uint256 gameNumber, bytes32 randao);
    event VDFProofSubmitted(address indexed submitter, uint256 gameNumber);
    event PrizesDistributed(uint256 gameNumber);
    event DifficultyChanged(uint256 gameNumber, Difficulty newDifficulty);
    event TicketPriceChangeScheduled(uint256 newPrice, uint256 effectiveGameNumber);
    event UnclaimedPrizeTransferred(uint256 fromGame, uint256 toGame, uint256 amount);

    constructor(address _vdfContractAddress) {
        vdfContract = VDFPietrzak(_vdfContractAddress);
        ticketPrice = 0.1 ether;
        currentGameNumber = 1;
        gameDifficulty[currentGameNumber] = Difficulty.Easy;
        lastDrawTime = block.timestamp;
    }

    // ticketing
    function buyTicket(uint256[3] memory numbers, uint256 etherball) external payable {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(validateNumbers(numbers, etherball, currentGameNumber), "Invalid numbers");

        uint256 gameNumber = currentGameNumber;

        // buy tickets
        bytes32 goldTicket = computeGoldTicketHash(numbers[0], numbers[1], numbers[2], etherball);
        bytes32 silverTicket = computeSilveTicketHash(numbers[0], numbers[1], numbers[2]);
        bytes32 bronzeTicket = computeBronzeTicketHash(numbers[0], numbers[1]);

        goldTickets[gameNumber][goldTicket].push(msg.sender);
        silverTickets[gameNumber][silverTicket].push(msg.sender);
        bronzeTickets[gameNumber][bronzeTicket].push(msg.sender);

        // update prize pool
        gamePrizePool[gameNumber] += msg.value;

        // update player info for loyalty program
        if (playerInfo[msg.sender].lastGamePlayed == gameNumber - 1) {
            playerInfo[msg.sender].consecutiveGamesPlayed += 1;
        } else if (playerInfo[msg.sender].lastGamePlayed < gameNumber) {
            playerInfo[msg.sender].consecutiveGamesPlayed = 1;
        }
        playerInfo[msg.sender].lastGamePlayed = gameNumber;

        emit TicketPurchased(msg.sender, gameNumber, numbers, etherball);
    }

    function buyBulkTickets(uint256[4][] calldata tickets) external payable {
        uint256 ticketCount = tickets.length;
        require(ticketCount > 0 && ticketCount <= 1000, "Invalid ticket count");
        require(msg.value == ticketPrice * ticketCount, "Incorrect total price");

        uint256 gameNumber = currentGameNumber;

        for (uint256 i = 0; i < ticketCount; i++) {
            uint256[3] memory numbers = [tickets[i][0], tickets[i][1], tickets[i][2]];
            uint256 etherball = tickets[i][3];

            require(validateNumbers(numbers, etherball, gameNumber), "Invalid numbers");

            bytes32 goldTicket = computeGoldTicketHash(numbers[0], numbers[1], numbers[2], etherball);
            bytes32 silverTicket = computeSilverTicketHash(numbers[0], numbers[1], numbers[2]);
            bytes32 bronzeTicket = computeBronzeTicketHash(numbers[0], numbers[1]);

            goldTickets[gameNumber][goldTicket].push(msg.sender);
            silverTickets[gameNumber][silverTicket].push(msg.sender);
            bronzeTickets[gameNumber][bronzeTicket].push(msg.sender);
        }

        // Update prize pool
        gamePrizePool[gameNumber] += msg.value;

        // Update player info for loyalty program
        if (playerInfo[msg.sender].lastGamePlayed == gameNumber - 1) {
            playerInfo[msg.sender].consecutiveGamesPlayed += 1;
        } else if (playerInfo[msg.sender].lastGamePlayed < gameNumber) {
            playerInfo[msg.sender].consecutiveGamesPlayed = 1;
        }
        playerInfo[msg.sender].lastGamePlayed = gameNumber;

        emit TicketsPurchased(msg.sender, gameNumber, ticketCount);
    }

    function validateNumbers(uint256[3] memory numbers, uint256 etherball, uint256 gameNumber) internal view returns (bool) {
        Difficulty difficulty = gameDifficulty[gameNumber];
        uint256 maxNumber;
        uint256 maxEtherball;

        if (difficulty == Difficulty.Easy) {
            maxNumber = EASY_MAX;
            maxEtherball = EASY_ETHERBALL_MAX;
        } else if (difficulty == Difficulty.Medium) {
            maxNumber = MEDIUM_MAX;
            maxEtherball = MEDIUM_ETHERBALL_MAX;
        } else {
            maxNumber = HARD_MAX;
            maxEtherball = HARD_ETHERBALL_MAX;
        }

        // Check numbers
        for (uint256 i = 0; i < 3; i++) {
            if (numbers[i] < 1 || numbers[i] > maxNumber) {
                return false;
            }
        }

        if (etherball < 1 || etherball > maxEtherball) {
            return false;
        }

        return true;
    }

    /* ticket prices can only be changed with a 4 game advance notice */
    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be positive");
        newTicketPrice = _newPrice;
        newTicketPriceGameNumber = currentGameNumber + 4;
        emit TicketPriceChangeScheduled(_newPrice, newTicketPriceGameNumber);
    }

    function computeBronzeTicketHash(uint256 numberOne, uint256 numberTwo) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo));
    }

    function computeSilveTicketHash(uint256 numberOne, uint256 numberTwo, uint256 numberThree) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo, numberThree));
    }

    function computeGoldTicketHash(uint256 numberOne, uint256 numberTwo, uint256 numberThree, uint256 etherball) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(numberOne, numberTwo, numberThree, etherball));
    }

    // drawing
    function initiateDraw() external {
        uint256 gameNumber = currentGameNumber;
        require(!gameDrawInitiated[gameNumber], "Draw already initiated for current game");
        require(block.timestamp >= lastDrawTime + DRAW_INTERVAL, "Time interval not passed");
        require(gamePrizePools[gameNumber] >= DRAW_MIN_PRIZE_POOL, "Insufficient prize pool");

        // Record the draw initiation
        lastDrawTime = block.timestamp;
        gameDrawInitiated[gameNumber] = true;

        uint256 currentBlock = block.number;
        uint256 currentEpoch = currentBlock / BLOCKS_PER_EPOCH;
        uint256 targetEpoch = currentEpoch + EPOCH_OFFSET;
        uint256 targetSetBlock = (targetEpoch * BLOCKS_PER_EPOCH) + BLOCK_OFFSET;
        gameRandaoBlockMin[gameNumber] = targetSetBlock;

        // Start the next game
        currentGameNumber += 1;
        if (newDifficulty && newDifficultyGame == currentGameNumber) {
            gameDifficulty[currentGameNumber] = newDifficulty;
        } else {
            gameDifficulty[currentGameNumber] = gameDifficulty[gameNumber];
        }

        emit DrawInitiated(gameNumber);
    }

    /* when the buffer period has passed, set block.prevRandao as seed for VDF func. anyone can take this and compute the VDF offchain. */
    function setRandao(uint256 gameNumber) external {
        require(gameDrawInitiated[gameNumber], "Draw not initiated for this game");
        require(block.number >= gameRandaoBlockMin[gameNumber], "Buffer period not yet passed");
        require(gameRandao[gameNumber] == bytes32(0), "Randao already set for this game");

        gameRandao[gameNumber] = block.prevrandao;
        emit RandaoSet(gameNumber, randao);
    }

    function submitVDFProof(uint256 gameNumber, bytes memory proof) external nonReentrant {
        require(gameRandao[gameNumber] != bytes32(0), "Randao not set for this game");
        require(!gameVDFValid[gameNumber], "VDF proof already submitted for this game");

        // Validate VDF proof using the VDF Pietrzak contract
        bool isValid = vdfContract.verifyVDF(proof, block.prevrandao);
        require(isValid, "Invalid VDF proof");

        gameVDFValid[gameNumber] = true;
        setWinningNumbers(gameNumber, proof);
        emit VDFProofSubmitted(msg.sender, gameNumber);
    }

    // Set winning numbers for the game
    function setWinningNumbers(uint256 gameNumber, bytes memory proof) internal {
        uint256 maxNumber;
        uint256 maxEtherball;

        if (currentDifficulty == Difficulty.Easy) {
            maxNumber = 25;
            maxEtherball = 10;
        } else if (currentDifficulty == Difficulty.Medium) {
            maxNumber = 50;
            maxEtherball = 20;
        } else {
            maxNumber = 75;
            maxEtherball = 30;
        }

        // Use the proof to generate random numbers
        bytes32 randomSeed = keccak256(proof);

        uint256[3] memory winningNumbers;
        for (uint256 i = 0; i < 3; i++) {
            winningNumbers[i] = (uint256(keccak256(abi.encodePacked(randomSeed, i))) % maxNumber) + 1;
        }
        winningNumbers[3] = (uint256(keccak256(abi.encodePacked(randomSeed, 3))) % maxEtherball) + 1;
        gameWinningNumbers[gameNumber] = winningNumbers;
    }

    // TODO: continue from here on forward

    // Distribute prizes for the game
    function calculatePayouts(uint256 gameNumber) internal {
        uint256 prizePool = gamePrizePool[gameNumber];
        uint256 goldPrize = (prizePool * GOLD_PERCENTAGE) / 10000;
        uint256 silverPrize = (prizePool * SILVER_PLACE_PERCENTAGE) / 10000;
        uint256 bronzePrize = (prizePool * BRONZE_PLACE_PERCENTAGE) / 10000;
        uint256 loyaltyPrize = (prizePool * LOYALTY_PERCENTAGE) / 10000;
        uint256 fee = (prizePool * FEE_PERCENTAGE) / 10000;

        // Calculate the prize per winner for each category
        uint256 goldWinners = goldTickets[gameNumber].length;
        uint256 silverWinners = silverTickets[gameNumber].length;
        uint256 bronzeWinners = bronzeTickets[gameNumber].length;

        uint256 goldPrizePerWinner = goldPrize / goldWinners;
        uint256 silverPrizePerWinner = silverPrize / silverWinners;
        uint256 bronzePrizePerWinner = bronzePrize / bronzeWinners;
    }

    function claimPrize(uint256 gameNumber) external {
        require(gameDrawCompleted[gameNumber], "Prizes not yet distributed for this game");
        require(!gameWinnerLoyaltyPrize[gameNumber][msg.sender], "Loyalty prize already claimed");

        uint256 loyaltyPrize = gamePayouts[gameNumber][3];
        gameWinnerLoyaltyPrize[gameNumber][msg.sender] = true;
        payable(msg.sender).transfer(loyaltyPrize);
    }

    function mintWinningNFT(uint256 gameNumber, uint256[] memory numbers, uint256 powerball) external nonReentrant {
        require(gameDrawn[gameNumber], "Game results not yet available");

        // Verify that the player has the winning ticket
        bytes32 ticketHash = computeTicketHash(numbers, powerball);
        PrizeCategory storage jackpotCategory = gamePrizeCategories[gameNumber][1];
        require(ticketHash == jackpotCategory.winningHash, "Not a winning ticket");

        // Verify that the player has not already minted an NFT
        // You may need to implement a mapping to track which players have minted NFTs

        // Mint NFT
        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);

        // Optionally set token URI
        // _setTokenURI(tokenId, "ipfs://...");

        emit NFTMinted(msg.sender, tokenId);
    }

    function releaseUnclaimedPrizes(uint256 gameNumber) external {
        require(gameDrawCompleted[gameNumber], "Prizes not yet distributed for this game");
        
        emit UnclaimedPrizeTransferred(i, currentGameNumber + 1, game.unclaimedPrize);

        require(totalReleased > 0, "No prizes to release");
    }
    /*  if 3+ jackpots, increase the difficulty. if 3+ no jackpots, decrease the difficulty. */
    function changeDifficulty(uint256 gameNumber) internal {
        bool jackpotWon = gameJackpotWon[gameNumber];

        if (jackpotWon) {
            consecutiveJackpots++;
            consecutiveNoJackpots = 0;
        } else {
            consecutiveNoJackpots++;
            consecutiveJackpots = 0;
        }

        Difficulty newDifficulty = gameDifficulty[gameNumber + 1]; // Next game's difficulty

        if (jackpotWon) {
            if (consecutiveJackpots >= 3 && gameDifficulty[gameNumber + 1] != Difficulty.Hard) {
                if (gameDifficulty[gameNumber + 1] == Difficulty.Easy) {
                    newDifficulty = Difficulty.Medium;
                } else if (gameDifficulty[gameNumber + 1] == Difficulty.Medium) {
                    newDifficulty = Difficulty.Hard;
                }
                consecutiveJackpots = 0;
                emit DifficultyChanged(gameNumber + 1, newDifficulty);
            }
        } else {
            if (consecutiveNoJackpots >= 3 && gameDifficulty[gameNumber + 1] != Difficulty.Easy) {
                if (gameDifficulty[gameNumber + 1] == Difficulty.Hard) {
                    newDifficulty = Difficulty.Medium;
                } else if (gameDifficulty[gameNumber + 1] == Difficulty.Medium) {
                    newDifficulty = Difficulty.Easy;
                }
                consecutiveNoJackpots = 0;
                emit DifficultyChanged(gameNumber + 1, newDifficulty);
            }
        }

        // Update the next game's difficulty if changed
        gameDifficulty[gameNumber + 1] = newDifficulty;
    }

    receive() external payable {}
}

// get randao for a game
// get current game difficulty
// get current prize pool
// get current game number
// get last draw time