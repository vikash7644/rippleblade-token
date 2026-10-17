const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const TOKEN_NAME = "RIPPLEBLADE";
  const TOKEN_SYMBOL = "RBLD";
  const TOTAL_SUPPLY = hre.ethers.parseUnits("10000000", 18);

  const QUICKSWAP_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  const USDT_ADDRESS = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";
  const TREASURY = deployer.address; // IMPORTANT: replace with multisig later

  const Token = await hre.ethers.getContractFactory("MyToken");
  const token = await Token.deploy(
    QUICKSWAP_ROUTER,
    USDT_ADDRESS,
    TREASURY
  );

  await token.deployed();
  console.log("Token deployed:", token.address);

  // Example: 100 tokens per 1 USDT
  const tokensPerUSDT = hre.ethers.parseUnits("100", 18);

  const Presale = await hre.ethers.getContractFactory("Presale");
  const presale = await Presale.deploy(token.address, USDT_ADDRESS, tokensPerUSDT);
  await presale.deployed();
  console.log("Presale deployed:", presale.address);

  // Presale should not be taxed
  const tx = await token.setFeeExempt(presale.address, true);
  await tx.wait();
  console.log("Presale marked fee-exempt");

  console.log("\nNext steps:");
  console.log("1) Send presale allocation to presale.address");
  console.log("2) Send airdrop reserve to presale.address");
  console.log("3) Buyers approve USDT for presale.buy()");
  console.log("4) After presale, run presale.finalize()");
  console.log("5) Add MYT/USDT liquidity on QuickSwap");
  console.log("6) After LP, run presale.setLPCreated()");
  console.log("7) Buyers call presale.claimPurchased() and presale.claimBonus()");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
