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

contract SpinWheelTest is Test, CodeConstants {
    DiceRoll public diceRoll;
    CoinFlip public coinFlip;
    SpinWheel public spinWheel;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 spinWheelEntranceFee;
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
        vm.deal(address(spinWheel), 10 ether);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        spinWheelEntranceFee = config.entranceFee;
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
        uint256 expectedEntranceFee = spinWheelEntranceFee;
        uint256 returnedEntranceFee = spinWheel.getEntranceFee();
        assertEq(returnedEntranceFee, expectedEntranceFee, "Entrance fee does not match the expected value");
    }

    function testInsufficientEntranceFee() public {
        vm.expectRevert(SpinWheel.SpinWheel__SendMoreToEnter.selector);
        spinWheel.spinWheel{value: spinWheelEntranceFee - 1}();
    }

    function testInitiateSpin() public {
        vm.prank(PLAYER);
        uint256 requestId = spinWheel.spinWheel{value: spinWheelEntranceFee}();
        assertNotEq(requestId, 0, "Request ID should be greater than 0");

        SpinWheel.SpinDetails memory spin = spinWheel.fetchSpinDetails(requestId);
        assertEq(spin.wagerAmount, spinWheelEntranceFee, "Wager amount does not match");
        assertEq(spin.player, PLAYER, "Player address is incorrect");
        assertFalse(spin.completed, "Spin should not be completed yet");
    }

    function testWithdrawFunds() public {
        uint256 contractBalanceBefore = address(spinWheel).balance;

        vm.prank(msg.sender);
        spinWheel.withdrawFunds();

        uint256 contractBalanceAfter = address(spinWheel).balance;
        assertEq(contractBalanceAfter, 0, "Contract balance should decrease after withdrawal");
        assertGt(contractBalanceBefore, contractBalanceAfter, "Contract balance should have decreased after withdrawal");
    }

    function testMultipleSpins() public {
        vm.prank(PLAYER);
        uint256 requestId1 = spinWheel.spinWheel{value: spinWheelEntranceFee}();
        vm.prank(PLAYER);
        uint256 requestId2 = spinWheel.spinWheel{value: spinWheelEntranceFee}();
        console2.log("RequestId2: ",requestId2);

        assertNotEq(requestId1, requestId2, "Each spin should have a unique request ID");
    }
}
