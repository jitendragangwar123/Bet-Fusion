// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployBetFusion} from "../../script/DeployBetFusion.s.sol";
import {DiceRoll} from "../../src/DiceRoll.sol";
import {CoinFlip} from "../../src/CoinFlip.sol";
import {SpinWheel} from "../../src/SpinWheel.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract CoinFlipTest is Test, CodeConstants {
    DiceRoll public diceRoll;
    CoinFlip public coinFlip;
    SpinWheel public spinWheel;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 coinFlipEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployBetFusion deployer = new DeployBetFusion();
        (diceRoll, coinFlip, spinWheel, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.deal(address(coinFlip), 1 ether);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        coinFlipEntranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function testGetEntranceFee() public view {
        uint256 expectedEntranceFee = coinFlipEntranceFee;
        uint256 returnedEntranceFee = coinFlip.getEntranceFee();
        assertEq(returnedEntranceFee, expectedEntranceFee, "Entrance fee does not match the expected value");
    }

    function testInsufficientEntranceFee() public {
        vm.expectRevert(CoinFlip.CoinFlip__SendMoreToEnterGame.selector);
        coinFlip.flip(CoinFlip.CoinFlipSelection.HEADS, true);
    }

    function testInitiateCoinFlip() public {
        vm.prank(PLAYER);
        uint256 requestId = coinFlip.flip{value: coinFlipEntranceFee}(CoinFlip.CoinFlipSelection.HEADS, true);
        assertNotEq(requestId, 0, "Request ID should be greater than 0");

        CoinFlip.CoinFlipStatus memory flipStatus = coinFlip.getFlipStatus(requestId);
        assertEq(flipStatus.stakedAmount, coinFlipEntranceFee, "Staked amount is incorrect");
        assertEq(flipStatus.player, PLAYER, "Player address is incorrect");
    }

    function testWithdrawFunds() public {
        uint256 contractBalanceBefore = address(coinFlip).balance;

        vm.prank(msg.sender);
        coinFlip.withdrawFunds();

        uint256 contractBalanceAfter = address(coinFlip).balance;
        assertEq(contractBalanceAfter, 0, "Contract balance should decrease after withdrawal");
        assertGt(contractBalanceBefore, contractBalanceAfter, "Contract balance should have decreased after withdrawal");
    }

    function testMultipleCoinFlips() public {
        vm.prank(PLAYER);
        uint256 requestId1 = coinFlip.flip{value: coinFlipEntranceFee}(CoinFlip.CoinFlipSelection.HEADS, true);
        vm.prank(PLAYER);
        uint256 requestId2 = coinFlip.flip{value: coinFlipEntranceFee}(CoinFlip.CoinFlipSelection.TAILS, true);

        assertNotEq(requestId1, requestId2, "Each flip should have a unique request ID");
    }

    function testCheckRequestStatus() public {
        vm.prank(PLAYER);
        uint256 requestId = coinFlip.flip{value: coinFlipEntranceFee}(CoinFlip.CoinFlipSelection.HEADS, true);

        (bool fulfilled, uint256[] memory randomWords) = coinFlip.getRequestStatus(requestId);
        assertFalse(fulfilled, "Request should not be fulfilled initially");
        assertEq(randomWords.length, 0, "Random words should be empty initially");
    }

    function testInitiateRollWithNativePaymentDisabled() public {
        vm.prank(PLAYER);
        uint256 requestId = coinFlip.flip{value: coinFlipEntranceFee}(CoinFlip.CoinFlipSelection.HEADS, true);
        assertNotEq(requestId, 0, "Request ID should be greater than 0");
    }
}
