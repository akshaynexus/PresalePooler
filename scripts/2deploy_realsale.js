// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const { ethers } = require("ethers");
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  let shitcoinAddr = "";
  let saleContractAddr = "";
  let peraddrLimit = ethers.utils.parseEther("25.0");
  let maxLimit = ethers.utils.parseEther("250");
  let MinSend = ethers.utils.parseEther("0.25");

  //Deploy pooler
  const PresalePoolerFactory = await ethers.getContractFactory(
    "PresalePoolerFactory"
  );
  let pooler = await PresalePoolerFactory.deploy(
    shitcoinAddr,
    saleContractAddr,
    peraddrLimit,
    maxLimit,
    MinSend
  );
  await pooler.deployed();
  console.log("Pooler deployed to:", pooler.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
