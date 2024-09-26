# Eat The Pie Lottery

Eat The Pie is an Ethereum-based lottery system utilizing Verifiable Delay Functions (VDF) for secure and fair random number generation.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Project Structure](#project-structure)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Interacting with Contracts](#interacting-with-contracts)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- [Solidity](https://docs.soliditylang.org/en/v0.8.25/)
- An Ethereum wallet with testnet ETH (for testnet deployments)

## Installation

1. Clone the repository:

   ```
   git clone https://github.com/yourusername/eat-the-pie.git
   cd eat-the-pie
   ```

2. Install dependencies:
   ```
   forge install
   ```

## Project Structure

```
eat-the-pie/
├── src/
│   ├── EatThePieLottery.sol
│   ├── NFTGenerator.sol
│   ├── VDFPietrzak.sol
│   └── libraries/
│       ├── BigNumbers.sol
│       └── PietrzakLibrary.sol
├── script/
│   └── DeployEatThePie.s.sol
├── test/
│   └── (test files)
├── .env
└── README.md
```

## Configuration

1. Create a `.env` file in the project root:

   ```
   PRIVATE_KEY=your_private_key_here
   RPC_URL=your_rpc_url_here
   ```

2. Update the `DeployEatThePie.s.sol` script with your specific parameters:
   - `n`: The RSA modulus for the VDF
   - `delta`: The VDF difficulty parameter
   - `T`: The VDF time parameter
   - `feeRecipient`: The address to receive lottery fees
   - `vdfModulusN`: The VDF modulus N

## Deployment

1. To deploy all contracts:

   ```
   forge script script/DeployEatThePie.s.sol:DeployEatThePie --rpc-url $RPC_URL --broadcast
   ```

2. For testnet/mainnet deployments with contract verification:
   ```
   forge script script/DeployEatThePie.s.sol:DeployEatThePie --rpc-url $RPC_URL --broadcast --verify
   ```

## Interacting with Contracts

After deployment, you can interact with the contracts using Forge's `cast` command or through a web3 interface.

1. Buy a lottery ticket:

   ```
   cast send <EatThePieLottery_ADDRESS> "buyTicket(uint256[3],uint256)" "[1,2,3]" "4" --value 0.1ether
   ```

2. Initiate a draw:

   ```
   cast send <EatThePieLottery_ADDRESS> "initiateDraw()"
   ```

3. Set random number:

   ```
   cast send <EatThePieLottery_ADDRESS> "setRandom(uint256)" <GAME_NUMBER>
   ```

4. Submit VDF proof:

   ```
   cast send <EatThePieLottery_ADDRESS> "submitVDFProof(uint256,uint256[],(uint256[],uint256))" <GAME_NUMBER> <V_VALUES> <Y_VALUE>
   ```

5. Calculate payouts:

   ```
   cast send <EatThePieLottery_ADDRESS> "calculatePayouts(uint256)" <GAME_NUMBER>
   ```

6. Claim prize:
   ```
   cast send <EatThePieLottery_ADDRESS> "claimPrize(uint256)" <GAME_NUMBER>
   ```

## Testing

Run the test suite:

```
forge test
```

For more verbose output:

```
forge test -vv
```

## Troubleshooting

- If you encounter "out of gas" errors during deployment, try increasing the gas limit:

  ```
  forge script script/DeployEatThePie.s.sol:DeployEatThePie --rpc-url $RPC_URL --broadcast --gas-limit 5000000
  ```

- For issues with contract verification, ensure you have the correct Etherscan API key set in your environment:

  ```
  export ETHERSCAN_API_KEY=your_api_key_here
  ```

- If you face issues with the VDF parameters, double-check the values in the deployment script and ensure they match your intended configuration.

For more detailed information about each contract and its functions, refer to the comments in the source code files.
