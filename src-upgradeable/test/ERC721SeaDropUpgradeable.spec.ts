import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

const now = () => Math.floor(Date.now() / 1000);

describe("ERC721SeaDropUpgradeable", () => {
  const publicDrop = {
    mintPrice: ethers.utils.parseEther("0.1"),
    maxTotalMintableByWallet: 10,
    startTime: now() - 100,
    endTime: now() + 100,
    feeBps: 1000,
    restrictFeeRecipients: true,
  };

  async function deployFixture() {
    const [owner, other, minter, feeRecipient] = await ethers.getSigners();

    const SeaDrop = await ethers.getContractFactory("MockSeaDropUpgradeable");
    const seaDrop = await SeaDrop.deploy();
    await seaDrop.deployed();

    const Token = await ethers.getContractFactory("ERC721SeaDropUpgradeable");
    const token = await upgrades.deployProxy(
      Token,
      ["Upgradeable SeaDrop", "USDP", [seaDrop.address]],
      { initializer: "initialize" }
    );

    return { owner, other, minter, feeRecipient, seaDrop, token };
  }

  it("restricts privileged operations to the owner and forwards configuration to SeaDrop", async () => {
    const { token, seaDrop, other, owner, feeRecipient } = await deployFixture();

    await expect(
      token.connect(other).updatePublicDrop(seaDrop.address, publicDrop)
    ).to.be.revertedWith("OnlyOwner");

    await expect(
      token.updatePublicDrop(seaDrop.address, publicDrop)
    ).to.not.be.reverted;

    const storedDrop = await seaDrop.getPublicDrop(token.address);
    expect(storedDrop.mintPrice).to.equal(publicDrop.mintPrice);
    expect(storedDrop.maxTotalMintableByWallet).to.equal(
      publicDrop.maxTotalMintableByWallet
    );

    await expect(
      token
        .connect(other)
        .updateCreatorPayoutAddress(seaDrop.address, owner.address)
    ).to.be.revertedWith("OnlyOwner");

    await token.updateCreatorPayoutAddress(seaDrop.address, owner.address);
    expect(await seaDrop.getCreatorPayoutAddress(token.address)).to.equal(
      owner.address
    );

    await token.updateAllowedFeeRecipient(
      seaDrop.address,
      feeRecipient.address,
      true
    );
    expect(
      await seaDrop.getFeeRecipientIsAllowed(token.address, feeRecipient.address)
    ).to.be.true;

    await token.updateAllowedFeeRecipient(
      seaDrop.address,
      feeRecipient.address,
      false
    );
    expect(
      await seaDrop.getFeeRecipientIsAllowed(token.address, feeRecipient.address)
    ).to.be.false;
  });

  it("only mints when invoked by an allowed SeaDrop contract", async () => {
    const { token, seaDrop, other, minter } = await deployFixture();

    await token.setMaxSupply(5);

    await expect(
      token.connect(other).mintSeaDrop(minter.address, 1)
    ).to.be.revertedWith("OnlyAllowedSeaDrop");

    await seaDrop.mintPublic(
      token.address,
      minter.address,
      minter.address,
      2
    );

    expect(await token.totalSupply()).to.equal(2);
    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
  });

  it("preserves state across upgrades", async () => {
    const { token, seaDrop, minter } = await deployFixture();

    await token.setBaseURI("ipfs://base/");
    await token.setContractURI("ipfs://contract.json");
    await token.setMaxSupply(10);

    const TokenV2 = await ethers.getContractFactory(
      "ERC721SeaDropUpgradeableV2"
    );
    const upgraded = await upgrades.upgradeProxy(token.address, TokenV2);

    expect(await upgraded.baseURI()).to.equal("ipfs://base/");
    expect(await upgraded.contractURI()).to.equal("ipfs://contract.json");
    expect(await upgraded.name()).to.equal("Upgradeable SeaDrop");
    expect(await upgraded.version()).to.equal("ERC721SeaDropUpgradeable_V2");

    await seaDrop.mintPublic(
      upgraded.address,
      minter.address,
      minter.address,
      1
    );
    expect(await upgraded.totalSupply()).to.equal(1);
  });
});
