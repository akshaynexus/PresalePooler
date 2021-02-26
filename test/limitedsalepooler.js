const { expect, assert } = require("chai");
// const { ethers } = require("ethers");
let saleLimited, tokenOfSaleLimited;
let pooler;
let saleUnlimited, tokenOfSaleUnlimited;
let owner, addr1, addr2, addr3, addrs;

function getAfterFee(val) {
  return val - val * 0.05;
}

describe("PresalePoolerFactory - Limited Sale", function () {
  it("Should setup limited sale", async function () {
    //Deploy sale token
    const MockToken = await ethers.getContractFactory("MockToken");
    tokenOfSaleLimited = await MockToken.deploy("SaleToken", "SLXT");
    //Deploy and set sale contract
    const MockPresaleLimited = await ethers.getContractFactory(
      "MockPresaleLimited"
    );
    const sale = await MockPresaleLimited.deploy();
    saleLimited = sale;
    //Set token of sale
    await saleLimited.setToken(tokenOfSaleLimited.address);
    //Mint 1mil and send it to sale contract
    await tokenOfSaleLimited.mint(ethers.utils.parseEther("1000000"));
    await tokenOfSaleLimited.transfer(
      saleLimited.address,
      ethers.utils.parseEther("1000000")
    );
    //Start sale
    await sale.startDistribution();
  });

  it("Should deploy the pooler", async function () {
    const PresalePoolerFactory = await ethers.getContractFactory(
      "PresalePoolerFactory"
    );
    pooler = await PresalePoolerFactory.deploy(
      tokenOfSaleLimited.address,
      saleLimited.address,
      ethers.utils.parseEther("10"),
      ethers.utils.parseEther("100"),
      0
    );
    await pooler.deployed();
    //Setup addrs
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
  });
  it("Should get iou when sending to pooler", async function () {
    let vals = [
      ethers.utils.parseEther("20.0"),
      ethers.utils.parseEther("50.0"),
      ethers.utils.parseEther("30.0"),
    ];
    let addrs = [addr1, addr2, addr3];
    for (let i = 0; i < addrs.length; i++) {
      //Send to sale
      await addrs[i].sendTransaction({
        to: pooler.address,
        value: vals[i],
      });
    }
    let baladd1 = await pooler.balanceOf(addr1.address);
    let baladd2 = await pooler.balanceOf(addr2.address);
    let baladd3 = await pooler.balanceOf(addr3.address);
    let balgov = await pooler.balanceOf(owner.address);
    let expectedBal1 = getAfterFee(vals[0]);
    let expectedBal2 = getAfterFee(vals[1]);
    let expectedBal3 = getAfterFee(vals[2]);
    let expectedBalGovFees = ethers.utils.parseEther("5"); //5% of 100
    //Check we got correct iou amounts
    assert(baladd1 == expectedBal1);
    assert(baladd2 == expectedBal2);
    assert(baladd3 == expectedBal3);
    //Check that governance got its fees
    assert(balgov == parseInt(expectedBalGovFees));
  });
  it("Should buy sale and claim tokens", async function () {
    await pooler.buy();
    await pooler.pullTokens();
  });
  it("Should get governance fees", async function () {
    await pooler.getGovFees();
  });
  it("Should claim tokens from pooled sale", async function () {
    let addrs = [addr1, addr2, addr3];
    for (let i = 0; i < addrs.length; i++) {
      await pooler.connect(addrs[i]).claimTokens();
    }
  });
  it("Should have 0 prepool token supply after all have claimed", async function () {
    let supply = await pooler.totalSupply();
    supply = parseInt(supply);
    assert(supply === 0);
  });
});
