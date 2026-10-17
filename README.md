# RIPPLEBLADE (RBLD)

Token overview
- Chain: Polygon
- Supply: 10,000,000 RBLD
- Decimals: 18
- Pair: RBLD / USDT
- Tax: 4%
  - 2% dev / treasury
  - 1% auto-liquidity
  - 1% burn
- Presale: USDT
- Bonus: buyers get 10% bonus when LP is created

## Quick start

1. npm install
2. cp .env.example .env
3. Fill PRIVATE_KEY and RPC endpoints
4. npx hardhat compile

## Deploy (Mumbai for testing)

- npx hardhat run scripts/deploy.js --network mumbai

## Post-deploy steps (manual)

1. Transfer presale allocation tokens to presale contract:
   - token.transfer(presaleAddress, presaleAllocation)
2. Transfer airdrop reserve tokens to presale contract (for 10% buyer bonus).
3. Start presale: buyers call presale.buy(amountUSDT) after approving USDT to presale.
4. Finalize presale: owner calls presale.finalize()
5. Buyers claim purchased tokens: presale.claimPurchased()
6. Create liquidity pool using a fee‑exempt wallet (owner/multisig):
   - approve token and USDT to QuickSwap Router and call addLiquidity(token, USDT, tokenAmount, usdtAmount, 0, 0, treasury, deadline)
7. After LP is created, owner calls presale.setLPCreated()
8. Buyers claim bonus: presale.claimBonus()
9. Lock LP tokens in a locker (e.g., TeamFinance, Unicrypt, or Gnosis Safe timelock)
10. Move treasury to multisig and enable governance protections.

## Security notes

- Treasury must be multisig (Gnosis Safe).
- Do not use a single EOA as long-term treasury.
- Audit the contracts before mainnet deployment.
- Add timelock or governance for sensitive admin functions.
- Consider Chainlink/Gelato for automating scheduled tasks (not required here).
