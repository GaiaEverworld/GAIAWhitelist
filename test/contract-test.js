const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Eever Land Contract", function () {
  let everland;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    const EverLand = await ethers.getContractFactory("EverLand");
    everland = await EverLand.deploy();
    await everland.deployed();
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    await everland.setMintEnabled(true);
    await everland.setPublicMintEnabled(true);
    await everland.setMerkleRoot(
      "0xe5bcd49d9fe98afcc1f91b1220ab81f0316bb471cefe249144b01f10885a9559"
    );
  });

  describe("functions", async function () {
    it("Set Mint Enable", async function () {
      expect(await everland.setMintEnabled(true));
    });

    it("Set Public Mint Enable", async function () {
      expect(await everland.setPublicMintEnabled(true));
    });

    it("Set Merkle Root", async function () {
      expect(
        await everland.setMerkleRoot(
          "0xe5bcd49d9fe98afcc1f91b1220ab81f0316bb471cefe249144b01f10885a9559"
        )
      );
    });

    it("Selected Mint", async function () {
      expect(
        await everland
          .connect(addr1)
          .selectedMint(3, [1, 2, 3], 1, 0x0bb8, [
            "0x1d7e0f7ec9b490bdeeab2678697d14da1fd1f898cd5f72040cf680d50d7a5d11",
            "0xfbf405cfc9858576f96fcaadc51e26f11e973b9eb69907997e868272232f2df5",
          ])
      );
    });

    it("Mint", async function () {
      expect(await everland.connect(addr1).mint(3, 0, 1));
    });

    it("OpenTrade", async function () {
      await everland.connect(addr1).mint(3, 0, 1);
      expect(
        await everland
          .connect(addr1)
          .openTrade(100002, "10000000000000000000", 1)
      );
    });

    it("CloseTrade", async function () {
      await everland.connect(addr1).mint(3, 0, 1);
      await everland
        .connect(addr1)
        .openTrade(100002, "10000000000000000000", 1);
      expect(await everland.connect(addr1).closeTrade(100002));
    });

    it("BuyToken", async function () {
      await everland.connect(addr1).mint(3, 0, 1);
      await everland
        .connect(addr1)
        .openTrade(100002, "10000000000000000000", 1);
      expect(
        await everland.connect(addr2).buyToken(100002, "10000000000000000000")
      );
    });
  });
});
