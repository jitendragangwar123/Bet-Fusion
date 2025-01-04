// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DiceRoll} from "../src/DiceRoll.sol";
import {CoinFlip} from "../src/CoinFlip.sol";
import {SpinWheel} from "../src/SpinWheel.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interaction.s.sol";

contract DeployBetFusion is Script {
    function run() external returns (DiceRoll, CoinFlip, SpinWheel, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        DiceRoll diceRoll = new DiceRoll(
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            config.entranceFee,
            config.vrfCoordinatorV2_5
        );
        CoinFlip coinFlip = new CoinFlip(
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            config.entranceFee,
            config.vrfCoordinatorV2_5
        );

        SpinWheel spinWheel = new SpinWheel(
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            config.entranceFee,
            config.vrfCoordinatorV2_5
        );

        vm.stopBroadcast();

        addConsumer.addConsumer(address(diceRoll), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        addConsumer.addConsumer(address(coinFlip), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        addConsumer.addConsumer(address(spinWheel), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        return (diceRoll, coinFlip, spinWheel, helperConfig);
    }
}
