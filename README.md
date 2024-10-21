![Eat The Pie](https://github.com/eatthepie/docs/blob/main/static/img/header.png)

# Eat The Pie Smart Contracts

This repository contains all smart contracts running Eat The Pie, a decentralized lottery on Ethereum using VDFs for random number generation.

## Project Structure

- `script/`: Deployment scripts

  - `DeployLottery.s.sol`
  - `DeployVDF.s.sol`

- `src/`: Main contract files

  - `libraries/`: Utility libraries
    - `BigNumbers.sol`
    - `PietrzakLibrary.sol`
  - `Lottery.sol`: Main lottery contract
  - `NFTPrize.sol`: NFT prize contract
  - `VDFPietrzak.sol`: Verifiable Delay Function implementation

- `test/`: Test files

  - `mocks/`: Mock contracts for testing
  - Test files:
    - `lotteryBasic.t.sol`: Basic lottery functionality tests
    - `lotteryClaims.t.sol`: Prize claiming tests
    - `lotteryDrawing.t.sol`: Lottery drawing process tests
    - `lotteryPayouts.t.sol`: Payout mechanism tests
    - `lotteryTicketing.t.sol`: Ticket purchase and management tests
    - `lotteryVdf.t.sol`: VDF integration tests
    - `vdf.t.sol`: Standalone VDF tests

- `test-vdf-files/`: VDF test files
  - `invalid/`: Invalid VDF test cases
  - `valid/`: Valid VDF test cases

## Setup

1. Install Foundry if you haven't already:

   ```
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Clone the repository:

   ```
   git clone https://github.com/eatthepie/contracts
   cd contracts
   ```

3. Install dependencies:
   ```
   forge install
   ```

## Deployment

To deploy the contracts to a network:

1. Set up your `.env` file with the required environment variables (e.g., RPC_URL, PRIVATE_KEY).

2. Run the deployment script:
   ```
   forge script script/DeployLottery.s.sol:DeployLottery --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
   ```

## Testing 🧪

Run the test suite with:

```
forge test
```

For more verbose output:

```
forge test -vv
```

To run a specific test file:

```
forge test --match-path test/[TestFileName].t.sol
```

## Documentation 📚

For detailed information about our smart contracts and how they work, please visit our [in-depth documentation](https://docs.eatthepie.xyz).

## License

This project is licensed under the MIT License.
