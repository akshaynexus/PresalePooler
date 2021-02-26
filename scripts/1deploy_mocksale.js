// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const { ethers } = require("ethers");
const hre = require("hardhat");
let owner, addr1, addr2, addr3, addrs;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

  // We get the contract to deploy
  const Shitcoin = await hre.ethers.getContractFactory("MockToken");
  const shitcoin = await Shitcoin.deploy("TestToken", "TXST");
  await shitcoin.deployed();
  console.log("Shitcoin deployed to:", shitcoin.address);
  //Deploy simple sale
  const SimpleSale = await hre.ethers.getContractFactory("SimplePresale");
  const sale = await SimpleSale.deploy();
  await sale.deployed();
  console.log("Sale deployed to:", sale.address);
  //Mint 1mil and send it to sale contract
  await shitcoin.mint(ethers.utils.parseEther("1000000"));
  await shitcoin.transfer(sale.address, ethers.utils.parseEther("1000000"), {
    gasLimit: 120000,
  });
  //Set token
  await sale.setToken(shitcoin.address);
  //Commence sale
  await sale.startDistribution();
  //Deploy pooler
  const PresalePoolerFactory = await ethers.getContractFactory(
    "PresalePoolerFactory"
  );
  let pooler = await PresalePoolerFactory.deploy(
    shitcoin.address,
    sale.address,
    ethers.utils.parseEther("0.1"),
    ethers.utils.parseEther("1"),
    0
  );
  await pooler.deployed();
  console.log("Pooler deployed to:", pooler.address);
  //Send to sale
  await addr1.sendTransaction({
    to: pooler.address,
    value: ethers.utils.parseEther("0.99"),
  });
  await pooler.buy({
    gasLimit: 12000000,
  });
  //Pull from proxies to main contract
  await pooler.pullTokens({
    gasLimit: 12000000,
  });
  //Get presale allocation
  await pooler.connect(addr1).claimTokens();
  //Get governance share
  await pooler.getGovFees();
  //Get back eth from sale contract
  await sale.claimTeamFeeAndAddLiquidity();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
