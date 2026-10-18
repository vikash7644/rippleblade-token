const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const QUICKSWAP_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  const USDT_ADDRESS = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";

  // Read TREASURY from env if provided (recommended to set to a multisig in GitHub Secrets or .env)
  const TREASURY = process.env.TREASURY || deployer.address;

  console.log("Using treasury:", TREASURY);

  const Token = await hre.ethers.getContractFactory("MyToken");
  const token = await Token.deploy(QUICKSWAP_ROUTER, USDT_ADDRESS, TREASURY);
  await token.deployed();
  console.log("Token deployed:", token.address);

  // Example: 100 tokens per 1 USDT (18-decimal token units)
  const tokensPerUSDT = hre.ethers.parseUnits("100", 18);

  const Presale = await hre.ethers.getContractFactory("Presale");
  const presale = await Presale.deploy(token.address, USDT_ADDRESS, tokensPerUSDT);
  await presale.deployed();
  console.log("Presale deployed:", presale.address);

  // Presale should not be taxed
  const tx = await token.setFeeExempt(presale.address, true);
  await tx.wait();
  console.log("Presale marked fee-exempt");

  console.log("\nPOST-DEPLOY STEPS (manual):");
  console.log("1) Transfer presale allocation tokens from deployer -> presale contract");
  console.log("   e.g., token.transfer(presale.address, presaleAllocation)");
  console.log("2) Transfer airdrop reserve tokens (for 10% bonuses) to presale contract");
  console.log("3) Start presale (buyers call presale.buy(usdtAmount) after approving USDT)");
  console.log("4) After presale, call presale.finalize()");
  console.log("5) Buyers claim purchased tokens: presale.claimPurchased()");
  console.log("6) Create LP on QuickSwap using deployer/multisig (fee-exempt account), pair RBLD/USDT.");
  console.log("7) After LP created, owner calls presale.setLPCreated()");
  console.log("8) Buyers claim bonus: presale.claimBonus()");
  console.log("9) Consider locking LP tokens and moving treasury to multisig.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
