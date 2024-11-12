// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BTCPriceBetting
 * @dev A decentralized betting contract for predicting Bitcoin price movements.
 * Author: ariutokintumi <3
 */

interface IFeedRegistry {
    function latestRoundData(address base, address quote)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,      // price
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title ReentrancyGuard
 * @dev Contract module that helps prevent reentrant calls to a function.
 */
contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }
}

/**
 * @title MockFeedRegistry
 * @dev Mock implementation of the IFeedRegistry interface for testing purposes.
 */
contract MockFeedRegistry is IFeedRegistry {
    // Mapping to store mock prices based on base and quote addresses
    mapping(address => mapping(address => int256)) private prices;

    /**
     * @dev Sets the mock price for a given base and quote pair.
     * @param base The base asset address.
     * @param quote The quote asset address.
     * @param price The mock price to set.
     */
    function setMockPrice(address base, address quote, int256 price) external {
        prices[base][quote] = price;
    }

    /**
     * @dev Returns the latest round data for a given base and quote pair.
     * @param base The base asset address.
     * @param quote The quote asset address.
     * @return roundId Mock round ID.
     * @return answer The mock price.
     * @return startedAt Mock start timestamp.
     * @return updatedAt Mock updated timestamp.
     * @return answeredInRound Mock answered in round ID.
     */
    function latestRoundData(address base, address quote)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,      // price
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(prices[base][quote] > 0, "Price not set for this pair");
        return (1, prices[base][quote], block.timestamp, block.timestamp, 1);
    }
}

/**
 * @title BTCPriceBetting
 * @dev Decentralized betting contract for predicting Bitcoin price movements.
 */
contract BTCPriceBetting is ReentrancyGuard {
    // Bets storage
    struct Bet {
        uint256 id;                   // NNN
        uint256 variation;            // PPP
        uint256 startTime;
        uint256 endTime;
        int256 startPrice;
        bool settled;
        uint256 totalPot;
        uint256 totalWinnersStakes;
        uint256[] winningOptions;
        mapping(uint256 => uint256) totalStakes; // Option => total bet
        mapping(uint256 => mapping(address => uint256)) stakes; // Option => user => amount bet
        mapping(address => bool) hasClaimed; // user => has claimed reward
        uint256 executorReward; // settleBet executor reward
    }

    // Bet information return
    struct BetInfo {
        uint256 id;
        uint256 variation;
        uint256 startTime;
        uint256 endTime;
        int256 startPrice;
        bool settled;
        uint256 totalPot;
        uint256 totalWinnersStakes;
        uint256[] winningOptions;
        uint256 executorReward;
    }

    // Bets id mapping
    mapping(uint256 => Bet) private bets;

    // Array of all bet ids
    uint256[] private betIds;

    // Oracle info
    IFeedRegistry public feedRegistry;
    address public baseAddress = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB; 
    address public quoteAddress = 0x0000000000000000000000000000000000000348;

    // cBTC decimals
    uint256 public constant DECIMALS = 8;

    // Executor reward percentage (in basis points, 10000 = 100%)
    uint256 public constant EXECUTOR_REWARD_PERCENT = 1; // 0.01%

    // Events
    event BetCreated(uint256 indexed id, uint256 variation, address indexed creator);
    event BetPlaced(uint256 indexed id, uint256 option, address indexed bettor, uint256 amount);
    event BetSettled(uint256 indexed id, uint256[] winningOptions, address indexed executor);
    event RewardClaimed(uint256 indexed id, address indexed claimant, uint256 amount);

    /**
     * @dev Constructor sets the Feed Registry Oracle address.
     * @param _feedRegistry Address of the Feed Registry Oracle.
     */
    constructor(address _feedRegistry) {
        require(_feedRegistry != address(0), "Invalid feed registry address");
        feedRegistry = IFeedRegistry(_feedRegistry);
    }

    /**
     * @dev Function to create a new bet.
     * @notice The sender must send exactly 0.00PPPNNN cBTC.
     */
    function createBet() external payable {
        // Extract PPP and NNN from msg.value
        uint256 value = msg.value;
        uint256 PPPNNN = value % 100000; // Last 5 digits are the satoshis input
        uint256 PPP = PPPNNN / 1000;     // Variation from 0 to 999
        uint256 NNN = PPPNNN % 1000;     // Bet id from 0 to 999

        uint256 amount = value - PPPNNN; // Amount that should be zero when creating the bet

        require(amount == 0, "Amount must be zero when creating a bet");
        require(PPP > 0 && PPP <= 999, "Invalid variation PPP");
        require(NNN <= 999, "Invalid bet id NNN");

        // Check if bet id already exists
        require(bets[NNN].id == 0, "Bet id already exists");

        // Create new bet
        Bet storage newBet = bets[NNN];
        newBet.id = NNN;
        newBet.variation = PPP;
        newBet.startTime = block.timestamp;
        newBet.endTime = block.timestamp + 7 days; // 1 week duration
        newBet.settled = false;
        newBet.startPrice = getLatestPrice();

        // Add this bet id to the list of bet IDs
        betIds.push(NNN);

        emit BetCreated(NNN, PPP, msg.sender);
    }

    /**
     * @dev Function to participate in an existing bet.
     * @param option The option chosen by the bettor (0 to PPP).
     * @param betId The ID of the bet to participate in.
     */
    function placeBet(uint256 option, uint256 betId) external payable {
        uint256 value = msg.value;
        uint256 PPPNNN = value % 100000; // Last 5 digits
        uint256 PPP = PPPNNN / 1000;     // Option chosen 
        uint256 NNN = PPPNNN % 1000;     // Bet id

        uint256 amount = value - PPPNNN; // Amount staked

        require(amount > 0, "Bet amount must be greater than zero");
        require(NNN <= 999, "Invalid bet id NNN");
        require(option <= 999, "Invalid option PPP");

        // Check if the bet exists
        Bet storage bet = bets[NNN];
        require(bet.id != 0, "Bet id does not exist");

        // Check that the option is valid for this bet
        require(option <= bet.variation, "Invalid option PPP");

        // Check that the betting period is still open
        require(block.timestamp <= bet.startTime + 1 days, "Betting period is over");

        // Write the user bet
        bet.stakes[option][msg.sender] += amount;
        bet.totalStakes[option] += amount;
        bet.totalPot += amount;

        emit BetPlaced(NNN, option, msg.sender, amount);
    }

    /**
     * @dev Function to settle a bet after its duration has ended.
     * @param NNN The ID of the bet to settle.
     */
    function settleBet(uint256 NNN) external nonReentrant {
        Bet storage bet = bets[NNN];
        require(bet.id != 0, "Bet does not exist");
        require(!bet.settled, "Bet already settled");
        require(block.timestamp >= bet.endTime, "Betting period not over");

        int256 endPrice = getLatestPrice();

        // Calculate the percentage change (using 4 extra decimals for precision)
        int256 priceChange = ((endPrice - bet.startPrice) * 10000) / bet.startPrice;

        // Maximum change in basis points
        int256 maxChange = (int256(bet.variation) * 10000) / 2;

        // Maximum possible difference
        uint256 maxDifference = uint256(abs(maxChange * 2));

        bool foundWinners = false;

        // Number of options (0 to bet.variation inclusive)
        uint256 numOptions = bet.variation + 1;

        // Loop to find winning options starting from the smallest difference
        for (uint256 difference = 0; difference <= maxDifference; difference++) {
            for (uint256 i = 0; i < numOptions; i++) {
                // optionChange = ((i * 2 * maxChange) / bet.variation) - maxChange
                int256 optionChange = ((int256(i) * 2 * maxChange) / int256(bet.variation)) - maxChange;
                uint256 currentDifference = abs(priceChange - optionChange);

                if (currentDifference == difference) {
                    if (bet.totalStakes[i] > 0) {
                        bet.winningOptions.push(i);
                        bet.totalWinnersStakes += bet.totalStakes[i];
                        foundWinners = true;
                    }
                }
            }
            if (foundWinners) {
                break;
            }
        }

        require(bet.totalWinnersStakes > 0, "No winners in this bet");

        // Calculate the reward for the executor
        bet.executorReward = (bet.totalPot * EXECUTOR_REWARD_PERCENT) / 10000;

        // Mark the bet as settled
        bet.settled = true;

        // Transfer the reward to the executor
        if (bet.executorReward > 0) {
            (bool sent, ) = msg.sender.call{value: bet.executorReward}("");
            require(sent, "Failed to send executor reward");
            bet.totalPot -= bet.executorReward;
        }

        emit BetSettled(NNN, bet.winningOptions, msg.sender);
    }

    /**
     * @dev Function for winners to claim their reward.
     * @param NNN The ID of the bet to claim reward from.
     */
    function claimReward(uint256 NNN) external nonReentrant {
        Bet storage bet = bets[NNN];
        require(bet.id != 0, "Bet id does not exist");
        require(bet.settled, "Bet not settled yet");
        require(!bet.hasClaimed[msg.sender], "Reward already claimed");

        uint256 userWinningStake = 0;

        // Check if the user has stakes in the winning options
        for (uint256 i = 0; i < bet.winningOptions.length; i++) {
            uint256 winningOption = bet.winningOptions[i];
            uint256 stake = bet.stakes[winningOption][msg.sender];
            if (stake > 0) {
                userWinningStake += stake;
            }
        }

        require(userWinningStake > 0, "No winnings to claim");

        // Calculate the payout
        uint256 payout = (bet.totalPot * userWinningStake) / bet.totalWinnersStakes;

        // Mark as claimed
        bet.hasClaimed[msg.sender] = true;

        // Transfer the payout to the user
        (bool sent, ) = msg.sender.call{value: payout}("");
        require(sent, "Failed to send payout");

        emit RewardClaimed(NNN, msg.sender, payout);
    }

    /**
     * @dev Internal function to get the latest BTC price from the Oracle.
     * @return price The latest BTC price.
     */
    function getLatestPrice() internal view returns (int256 price) {
        (, price, , , ) = feedRegistry.latestRoundData(baseAddress, quoteAddress);
        require(price > 0, "Invalid price from oracle");
    }

    /**
     * @dev Internal pure function to calculate the absolute value of an int256.
     * @param x The integer to get the absolute value of.
     * @return The absolute value as uint256.
     */
    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    /**
     * @dev External view function to get information about a specific bet.
     * @param NNN The ID of the bet to retrieve information for.
     * @return betInfo A BetInfo struct containing the bet details.
     */
    function getBetInfo(uint256 NNN) external view returns (BetInfo memory betInfo) {
        Bet storage bet = bets[NNN];
        require(bet.id != 0, "Bet id does not exist");

        betInfo = BetInfo({
            id: bet.id,
            variation: bet.variation,
            startTime: bet.startTime,
            endTime: bet.endTime,
            startPrice: bet.startPrice,
            settled: bet.settled,
            totalPot: bet.totalPot,
            totalWinnersStakes: bet.totalWinnersStakes,
            winningOptions: bet.winningOptions,
            executorReward: bet.executorReward
        });
    }

    /**
     * @dev External view function to get all active (unsettled) bet IDs.
     * @return activeIds An array of active bet IDs.
     */
    function getActiveBetIds() external view returns (uint256[] memory activeIds) {
        uint256 totalBets = betIds.length;
        uint256 activeCount = 0;

        // Count the number of active bets
        for (uint256 i = 0; i < totalBets; i++) {
            if (!bets[betIds[i]].settled) {
                activeCount++;
            }
        }

        // Create an array of the appropriate size
        activeIds = new uint256[](activeCount);
        uint256 index = 0;

        // Populate the array with active bet ids
        for (uint256 i = 0; i < totalBets; i++) {
            if (!bets[betIds[i]].settled) {
                activeIds[index] = betIds[i];
                index++;
            }
        }
    }
}
