![Eat The Pie](https://github.com/eatthepie/docs/blob/main/static/img/header.png)

# Eat The Pie Layer 2 Smart Contracts

This repository contains all smart contracts running [Eat The Pie](https://www.eatthepie.xyz), the world lottery on World Chain.

## Project Structure 📂

- `script/`: Deployment scripts

  - `DeployLottery.s.sol`
  - `DeployVDF.s.sol`

- `src/`: Main contract files

  - `Lottery.sol`: Main lottery contract
  - `NFTPrize.sol`: NFT prize contract

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
   source .env
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

## 📝 Deployed Contracts

| Network     | Address                                      |
| ----------- | -------------------------------------------- |
| World Chain | `0x86510c295644D1214Dc62112E15ec314076AcF2c` |

## Documentation 📚

For detailed information about the smart contracts and how they work, please visit [docs.eatthepie.xyz](https://docs.eatthepie.xyz).

## License 📜

This project is licensed under the MIT License.
