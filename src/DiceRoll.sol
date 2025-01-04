// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title BetFusion : DiceRoll
 * @dev A contract for a dice-based wagering game using Chainlink VRF for randomness.
 * Players can bet on the sum of two dice rolls being above or below six.
 */
contract DiceRoll is VRFConsumerBaseV2Plus {
    /**
     * @dev Thrown when the sent value is less than the required entrance fee.
     */
    error DiceRoll__SendMoreToEnterGame();

    /// @dev Enum to represent roll options: ABOVE_SIX or BELOW_SIX.
    enum RollOption {
        ABOVE_SIX,
        BELOW_SIX
    }

    /**
     * @dev Structure to track the details of a roll.
     * @param wagerAmount The amount wagered by the participant.
     * @param firstRandomValue The first dice roll result.
     * @param secondRandomValue The second dice roll result.
     * @param participant The address of the player.
     * @param isWinner Indicates if the player won the roll.
     * @param completed Indicates if the roll is completed.
     * @param selection The player's chosen roll option.
     */
    struct RollDetails {
        uint256 wagerAmount;
        uint256 firstRandomValue;
        uint256 secondRandomValue;
        address participant;
        bool isWinner;
        bool completed;
        RollOption selection;
    }

    /**
     * @dev Structure to track the status of a random number request
     * @param fulfilled Whether the request has been successfully fulfilled by Chainlink VRF
     * @param exists Whether a requestId exists in the mapping
     * @param randomWords Array of random values returned from Chainlink VRF
     */
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    /// @dev Mapping of request IDs to roll details.
    mapping(uint256 => RollDetails) public s_rollStatuses;

    /// @dev Mapping of request IDs to their status.
    mapping(uint256 => RequestStatus) public s_requests;

    /// @dev Entrance Fees to enter game
    uint256 private immutable i_entranceFee;

    /// @dev Player's addresses
    address payable[] private s_players;

    /// @dev Subscription ID for Chainlink VRF.
    uint256 private immutable i_subscriptionId;

    /// @dev Key hash for Chainlink VRF.
    bytes32 private immutable i_keyHash;

    /// @dev Gas limit for callback processing.
    uint32 private immutable i_callbackGasLimit;

    /// @dev Number of confirmations required for the random request.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @dev Number of random values to request.
    uint32 private constant NUM_WORDS = 2;

    /// @dev List of past request IDs.
    uint256[] public s_requestIds;

    /// @dev Last request ID generated.
    uint256 public s_lastRequestId;

    /**
     * @notice Emitted when a roll is initiated.
     * @param requestId The unique request ID for the roll.
     */
    event RollInitiated(uint256 requestId);
    /**
     *  @notice Emitted when a roll outcome is determined.
     *  @param requestId The unique request ID for the roll.
     *  @param isWinner Indicates if the participant won the roll.
     */
    event RollOutcome(uint256 requestId, bool isWinner);

    /**
     * @notice Emitted when a random number request is sent.
     * @param requestId The unique request ID for randomness.
     * @param numWords The number of random values requested.
     */
    event RequestSent(uint256 requestId, uint32 numWords);

    /**
     * @notice Emitted when a random number request is fulfilled.
     * @param requestId The unique request ID for randomness.
     * @param randomWords The array of random values generated.
     */
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    /**
     * @notice Emitted when a player enters the dice roll game.
     * @dev This event is triggered when a player participates in the game.
     * @param player The address of the player who entered the dice roll game.
     */
    event EnteredDiceRoll(address indexed player);

    /**
     * @notice Constructor to initialize the contract.
     * @param subscriptionId The subscription ID for funding Chainlink VRF requests.
     */
    constructor(
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 entranceFee,
        address _VRFConsumerBaseV2Plus
    ) VRFConsumerBaseV2Plus(_VRFConsumerBaseV2Plus) {
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_entranceFee = entranceFee;
    }

    /**
     * @notice Allows the contract to receive native tokens.
     */
    receive() external payable {}

    /**
     * @notice Function to withdraw the balance of the contract
     * @dev Only the owner can call this function
     */
    function withdrawFunds() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(contractBalance);
    }

    /**
     * @notice Initiates a dice roll game.
     * @param selection The player's roll option (ABOVE_SIX or BELOW_SIX).
     * @param enableNativePayment Whether to enable payment in native tokens.
     * @return requestId The unique ID of the randomness request.
     */
    function initiateRoll(RollOption selection, bool enableNativePayment)
        external
        payable
        returns (uint256 requestId)
    {
        if (msg.value < i_entranceFee) {
            revert DiceRoll__SendMoreToEnterGame();
        }
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}))
            })
        );
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});

        // update roll status
        s_rollStatuses[requestId] = RollDetails({
            wagerAmount: msg.value,
            firstRandomValue: 0,
            secondRandomValue: 0,
            participant: msg.sender,
            isWinner: false,
            completed: false,
            selection: selection
        });
        s_players.push(payable(msg.sender));
        s_requestIds.push(requestId);
        s_lastRequestId = requestId;
        emit RequestSent(requestId, NUM_WORDS);
        emit RollInitiated(requestId);
        emit EnteredDiceRoll(msg.sender);
        return requestId;
    }

    /**
     * @notice Callback function to handle randomness fulfillment.
     * @param _requestId The unique ID of the randomness request.
     * @param _randomWords The random values generated by Chainlink VRF.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);

        // update roll status
        s_rollStatuses[_requestId].completed = true;
        s_rollStatuses[_requestId].firstRandomValue = (_randomWords[0] % 6) + 1;
        s_rollStatuses[_requestId].secondRandomValue = (_randomWords[1] % 6) + 1;

        // determine roll outcome
        RollOption outcome = RollOption.BELOW_SIX;

        if ((((_randomWords[0] % 6) + 1) + ((_randomWords[1] % 6) + 1)) > 6) {
            outcome = RollOption.ABOVE_SIX;
        }

        // payout if the player wins
        if (s_rollStatuses[_requestId].selection == outcome) {
            s_rollStatuses[_requestId].isWinner = true;
            payable(s_rollStatuses[_requestId].participant).transfer(s_rollStatuses[_requestId].wagerAmount * 2);
        }

        emit RollOutcome(_requestId, s_rollStatuses[_requestId].isWinner);
    }

    /**
     * @notice Gets the status of a randomness request.
     * @param _requestId The unique ID of the randomness request.
     * @return fulfilled Indicates if the randomness was fulfilled.
     * @return randomWords The random values generated.
     */
    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    /**
     * @notice Fetches details of a specific roll.
     * @param requestId The unique ID of the roll.
     * @return The roll details as a RollDetails struct.
     */
    function fetchRollDetails(uint256 requestId) public view returns (RollDetails memory) {
        return s_rollStatuses[requestId];
    }

    /**
     * @notice Fetches the entrance fee required to participate in the Dice Roll game.
     * @dev The entrance fee is set during contract deployment and is immutable.
     * @return The entrance fee as a uint256 value, representing the amount in wei.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
