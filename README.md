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
  - Various test files for different lottery functionalities

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

   Replace `DeployLottery.s.sol` with the appropriate deployment script if needed.

## Testing

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

## Main Features

- Lottery functionality: Implements a decentralized lottery system on Ethereum.
- NFT prizes: Utilizes NFTs as lottery prizes, adding uniqueness to winnings.
- Verifiable Delay Function (VDF): Ensures fairness and unpredictability in the lottery draw.

## Usage

Interact with the deployed contracts using a wallet like MetaMask or programmatically through ethers.js or web3.js. Key functions include:

1. Buying lottery tickets
2. Checking ticket status
3. Claiming prizes
4. Verifying lottery results using VDF

Refer to the contract ABIs for detailed function signatures and event logs.

## License

This project is licensed under the MIT License.
