// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title BetFusion : CoinFlip
 * @dev A contract for a coin flip betting game using Chainlink VRF for randomness.
 * Players bet on whether the result of a coin flip will be HEADS or TAILS.
 */
contract CoinFlip is VRFConsumerBaseV2Plus {
    /**
     * @dev Thrown when the sent value is less than the required entrance fee.
     */
    error CoinFlip__SendMoreToEnterGame();

    /**
     * @dev Enum for coin flip selection: HEADS or TAILS.
     * @notice Represents the player's choice in the coin flip game.
     */
    enum CoinFlipSelection {
        HEADS,
        TAILS
    }

    /**
     * @dev Structure to track the status of a coin flip.
     * @notice Holds information about an individual coin flip game.
     */
    struct CoinFlipStatus {
        uint256 stakedAmount;
        uint256 randomWords;
        address player;
        bool didWin;
        bool fulfilled;
        bool completed;
        CoinFlipSelection choice;
    }

    /**
     * @dev Structure to track the status of a random number request.
     * @param fulfilled Whether the request has been successfully fulfilled by Chainlink VRF.
     * @param exists Whether a requestId exists in the mapping.
     * @param randomWords Array of random values returned from Chainlink VRF.
     */
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    /// @dev Mapping of request IDs to their coin flip statuses.
    mapping(uint256 => CoinFlipStatus) public s_flipStatuses;

    /// @dev Mapping of request IDs to their random number request statuses.
    mapping(uint256 => RequestStatus) public s_requests;

    /// @dev Entrance fee required to participate in the game.
    uint256 private immutable i_entranceFee;

    /// @dev List of players' addresses.
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
    uint32 private constant NUM_WORDS = 1;

    /// @dev List of past request IDs.
    uint256[] public s_requestIds;

    /// @dev Last request ID generated.
    uint256 public s_lastRequestId;

    /**
     * @dev Emitted when a coin flip is initiated.
     * @param requestId The unique ID of the randomness request.
     */
    event CoinFlipInitiated(uint256 requestId);

    /**
     * @dev Emitted when a coin flip result is determined.
     * @param requestId The unique ID of the randomness request.
     * @param didWin Indicates whether the player won or lost.
     */
    event CoinFlipResult(uint256 requestId, bool didWin);

    /**
     * @dev Emitted when a random number request is sent.
     * @param requestId The unique ID of the randomness request.
     * @param numWords The number of random words requested.
     */
    event RequestSent(uint256 requestId, uint32 numWords);

    /**
     * @dev Emitted when a random number request is fulfilled.
     * @param requestId The unique ID of the randomness request.
     * @param randomWords The random number generated.
     */
    event RequestFulfilled(uint256 requestId, uint256 randomWords);

    /**
     * @notice Emitted when a player enters the coin flip game.
     * @param player The address of the player who entered the game.
     */
    event EnteredCoinFlip(address indexed player);

    /**
     * @notice Constructor to initialize the contract.
     * @param subscriptionId The subscription ID for funding Chainlink VRF requests.
     * @param keyHash The key hash for Chainlink VRF.
     * @param callbackGasLimit The gas limit for processing the VRF callback.
     * @param entranceFee The entrance fee to participate in the game.
     * @param _VRFConsumerBaseV2Plus The address of the Chainlink VRF consumer base contract.
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
     * @notice Withdraws the contract balance.
     * @dev Only the owner can call this function.
     */
    function withdrawFunds() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(contractBalance);
    }

    /**
     * @notice Initiates a coin flip game.
     * @param choice The player's choice (HEADS or TAILS).
     * @param enableNativePayment Whether to enable native payment for VRF requests.
     * @return requestId The unique ID of the randomness request.
     */
    function flip(CoinFlipSelection choice, bool enableNativePayment) external payable returns (uint256 requestId) {
        if (msg.value < i_entranceFee) {
            revert CoinFlip__SendMoreToEnterGame();
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

        s_flipStatuses[requestId] = CoinFlipStatus({
            stakedAmount: msg.value,
            randomWords: 0,
            player: msg.sender,
            didWin: false,
            fulfilled: false,
            completed: false,
            choice: choice
        });
        s_players.push(payable(msg.sender));
        s_requestIds.push(requestId);
        s_lastRequestId = requestId;

        emit RequestSent(requestId, NUM_WORDS);
        emit CoinFlipInitiated(requestId);
        emit EnteredCoinFlip(msg.sender);
        return requestId;
    }

    /**
     * @notice Callback function to handle randomness fulfillment.
     * @param _requestId The unique ID of the randomness request.
     * @param _randomWords The random value generated by Chainlink VRF.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        require(s_requests[_requestId].exists, "Request not found");

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords[0]);

        s_flipStatuses[_requestId].completed = true;
        s_flipStatuses[_requestId].randomWords = _randomWords[0] % 2;

        CoinFlipSelection result = (_randomWords[0] % 2 == 0) ? CoinFlipSelection.HEADS : CoinFlipSelection.TAILS;

        if (s_flipStatuses[_requestId].choice == result) {
            s_flipStatuses[_requestId].didWin = true;
            payable(s_flipStatuses[_requestId].player).transfer(s_flipStatuses[_requestId].stakedAmount * 2);
        }
        emit CoinFlipResult(_requestId, s_flipStatuses[_requestId].didWin);
    }

    /**
     * @notice Fetches the status of a specific random number request.
     * @param _requestId The unique ID of the randomness request.
     * @return fulfilled Whether the request has been fulfilled.
     * @return randomWords The random values associated with the request.
     */
    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].exists, "Request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    /**
     * @notice Fetches the status of a specific coin flip.
     * @param requestId The unique ID of the coin flip.
     * @return The status of the coin flip as a CoinFlipStatus struct.
     */
    function getFlipStatus(uint256 requestId) external view returns (CoinFlipStatus memory) {
        return s_flipStatuses[requestId];
    }

    /**
     * @notice Fetches the entrance fee required to participate in the Coin Flip game.
     * @dev The entrance fee is set during contract deployment and is immutable.
     * @return The entrance fee as a uint256 value, representing the amount in wei.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
