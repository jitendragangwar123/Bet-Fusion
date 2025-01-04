// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title BetFusion: SpinWheel
 * @dev A contract for a spin wheel game using Chainlink VRF for randomness.
 * Players wager funds and spin the wheel. Payouts vary based on the result.
 */
contract SpinWheel is VRFConsumerBaseV2Plus {
    /// @notice Error thrown when the sent value is less than the required entrance fee.
    error SpinWheel__SendMoreToEnter();

    /**
     * @notice Stores details of each spin.
     * @param wagerAmount The amount wagered by the player.
     * @param randomResult The random result of the spin (0-5).
     * @param player The address of the player.
     * @param isWinner Whether the player won the spin.
     * @param completed Whether the spin has been completed.
     */
    struct SpinDetails {
        uint256 wagerAmount;
        uint256 randomResult;
        address player;
        bool isWinner;
        bool completed;
    }

    /**
     * @notice Tracks the status of a randomness request.
     * @param fulfilled Whether the randomness request has been fulfilled.
     * @param exists Whether the request exists.
     * @param randomWords The array of random values generated by Chainlink VRF.
     */
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    /// @dev Maps a randomness request ID to its spin details.
    mapping(uint256 => SpinDetails) public s_spinStatuses;

    /// @dev Maps a randomness request ID to its status.
    mapping(uint256 => RequestStatus) public s_requests;

    /// @notice The fee required to participate in the game.
    uint256 private immutable i_entranceFee;

    /// @notice The subscription ID for Chainlink VRF.
    uint256 private immutable i_subscriptionId;

    /// @notice The key hash used for randomness generation.
    bytes32 private immutable i_keyHash;

    /// @notice The gas limit for callback execution.
    uint32 private immutable i_callbackGasLimit;

    /// @notice Number of confirmations required for randomness request.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice Number of random values requested.
    uint32 private constant NUM_WORDS = 1;

    /// @notice Array of all request IDs.
    uint256[] public s_requestIds;

    /// @notice The last request ID generated.
    uint256 public s_lastRequestId;

    /**
     * @notice Emitted when a spin is initiated.
     * @param requestId The unique ID of the randomness request.
     * @param player The address of the player who initiated the spin.
     */
    event SpinInitiated(uint256 indexed requestId, address indexed player);

    /**
     * @notice Emitted when a spin is resolved.
     * @param requestId The unique ID of the randomness request.
     * @param isWinner Whether the player won the spin.
     * @param randomResult The random result of the spin.
     */
    event SpinResolved(uint256 indexed requestId, bool isWinner, uint256 randomResult);

    /**
     * @notice Emitted when randomness is fulfilled.
     * @param requestId The unique ID of the randomness request.
     * @param randomWords The array of random values generated.
     */
    event RandomnessFulfilled(uint256 indexed requestId, uint256[] randomWords);

    /**
     * @notice Initializes the contract with VRF parameters and entrance fee.
     * @param subscriptionId The subscription ID for Chainlink VRF.
     * @param keyHash The key hash for Chainlink VRF.
     * @param callbackGasLimit The gas limit for callback execution.
     * @param entranceFee The minimum fee to participate in the game.
     * @param _VRFConsumerBaseV2Plus The address of the VRFConsumerBaseV2Plus contract.
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
     * @notice Allows the owner to withdraw all funds from the contract.
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(balance);
    }

    /**
     * @notice Allows a player to initiate a spin by paying the entrance fee.
     * @return requestId The unique ID of the randomness request.
     */
    function spinWheel() external payable returns (uint256 requestId) {
        if (msg.value < i_entranceFee) {
            revert SpinWheel__SendMoreToEnter();
        }

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});

        s_spinStatuses[requestId] = SpinDetails({
            wagerAmount: msg.value,
            randomResult: 0,
            player: msg.sender,
            isWinner: false,
            completed: false
        });

        s_requestIds.push(requestId);
        s_lastRequestId = requestId;

        emit SpinInitiated(requestId, msg.sender);
        return requestId;
    }

    /**
     * @notice Callback to handle randomness fulfillment by Chainlink VRF.
     * @param requestId The unique ID of the randomness request.
     * @param randomWords The array of random values generated.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(s_requests[requestId].exists, "Request ID not found");

        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;
        emit RandomnessFulfilled(requestId, randomWords);

        SpinDetails storage spin = s_spinStatuses[requestId];
        spin.completed = true;

        // Calculate random result in range 0-5
        spin.randomResult = randomWords[0] % 6;

        // Determine winning conditions
        if (spin.randomResult == 0 || spin.randomResult == 4) {
            spin.isWinner = true;
            payable(spin.player).transfer(spin.wagerAmount);
        } else if (spin.randomResult == 1 || spin.randomResult == 5) {
            spin.isWinner = true;
            payable(spin.player).transfer(spin.wagerAmount * 2);
        } else if (spin.randomResult == 3) {
            spin.isWinner = true;
            payable(spin.player).transfer(spin.wagerAmount / 2);
        }

        emit SpinResolved(requestId, spin.isWinner, spin.randomResult);
    }

    /**
     * @notice Fetches the details of a spin by request ID.
     * @param requestId The unique ID of the spin.
     * @return The spin details as a `SpinDetails` struct.
     */
    function fetchSpinDetails(uint256 requestId) public view returns (SpinDetails memory) {
        return s_spinStatuses[requestId];
    }

    /**
     * @notice Fetches the entrance fee required to participate in the game.
     * @return The entrance fee in wei.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
