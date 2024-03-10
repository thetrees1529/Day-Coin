// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { ethers } = hre;
const initialLiq = BigInt(1e16)
const newLifespan = 600
const newToLP = BigInt(1e24)
const newDay = 1
const newDeadAt = Math.floor(Date.now() / 1000) + newLifespan
const newParent = ethers.ZeroAddress
const newRouter = "0x7E3411B04766089cFaa52DB688855356A12f05D1"

async function main() {

  const factory = await hre.ethers.deployContract("DayFactory");
  await factory.waitForDeployment();

  await (await factory.createNewDay(factory.target, newLifespan, newToLP, newDay, newDeadAt, newParent, newRouter, {value: initialLiq})).wait()

  console.log("DayFactory deployed to:", factory.target);

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
