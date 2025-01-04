# Bet Fusion 🎰
**Bet Fusion** is a decentralized betting game platform where players wager on **CoinFlip**, **SpinWheel**, and **DiceRoll**, each offering unique odds and rewards. With **Chainlink VRF**, every outcome is **provably fair** and **tamper-proof**, ensuring transparency and trust.

---
### 🚀 Features
- **Decentralized Gameplay**: Built on blockchain technology for fairness and security.
- **Provably Fair Outcomes**: Utilizes **Chainlink VRF** to ensure tamper-proof randomness.
- **Multiple Betting Options**: Choose from **coin flips**, **spins**, or **dice rolls** for diverse gameplay.
- **Dynamic Rewards**: Each game type offers unique odds and payout structures.
- **Global Leaderboards**: Compete with players worldwide and showcase your skills.
- **Immersive Experience**: Fast-paced gameplay with engaging animations and sound effects.
- **Cross-Platform Support**: Play seamlessly on **desktop** or **mobile** devices.
- **Community-Driven**: Regular updates and events driven by player feedback.
---

### 🛠 Requirements
Before you start, ensure that you have the following installed:
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Foundry](https://getfoundry.sh/)

### ⚡ Quickstart
Clone the repository and set up your environment:
```
$ git clone https://github.com/jitendragangwar123/Bet-Fusion.git
$ cd Bet-Fusion
$ make install
$ forge build
```

### 🌐 Start a Local Node
Run the following command to start your local node for testing and development:
```
$ make anvil
```

### 📚 Library
If you're having a hard time installing the Chainlink library, you can optionally run this command:
```
$ forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```

### 🚀 Deploy
This will default to your local node. You need to have it running in another terminal in order for the deployment to work.
```
$ make deploy
```

### 🧪 Testing

You can run tests in various environments:

1. **Unit Tests**
2. **Integration Tests**
3. **Forked Network Tests**
4. **Staging Tests**

To run all tests, use:

```
$ forge test
```
or

```
$ forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
$ forge coverage
```

### 🌍 Deployment to a Testnet or Mainnet

#### 1. Setup Environment Variables

You'll need to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file in your project directory.

Optionally, you can also add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

#### 2. Get Testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) to get some testnet ETH. The ETH should show up in your MetaMask wallet shortly.

#### 3. Deploy to Sepolia Testnet

To deploy your contract to the **Sepolia** testnet, run:

```
$ make deploy ARGS="--network sepolia"
```

This will setup a ChainlinkVRF Subscription for you. If you already have one, update it in the `scripts/HelperConfig.s.sol` file. It will also automatically add your contract as a consumer.


### ⛽ Estimate Gas

You can estimate how much gas transactions will cost by running:

```
$ forge snapshot
```

And you'll see an output file called `.gas-snapshot`

### 📝 Formatting

To run code formatting, use the following command:

```
$ forge fmt
```

### 🌐 Front-End

1. **Install the dependencies**:
```
$ npm i
```

2. **Start the client**:
```
$ npm run dev
```