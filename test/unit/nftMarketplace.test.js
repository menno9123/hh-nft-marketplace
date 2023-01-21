const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("NFT Marketplace Unit Tests", function () {
          let NftMarketplace, deployer, basicNFT, nftAddress, tokenId, price
          const chainId = network.config.chainId
          const listFee = networkConfig[chainId].listFee

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["all"])
              NftMarketplace = await ethers.getContract("NftMarketplace", deployer)
              basicNFT = await ethers.getContract("BasicNFT", deployer)
              nftAddress = basicNFT.address
          })

          describe("constructor", function () {
              it("Initializes the  NFT marketplace correctly", async function () {
                  const listingFee = await NftMarketplace.getListFee()
                  assert.equal(listingFee.toString(), networkConfig[chainId].listFee.toString())
              })
          })

          describe("listItem", function () {
              beforeEach(async function () {})
              it("does not list if msg.value is less than listFee", async function () {
                  price = 0
                  tokenId = 0
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: ethers.utils.parseEther("0.0001"),
                      })
                  ).to.be.revertedWith("NftMarketplace__NotEnoughEthForListFee")
              })

              //   it("does not list if price of NFT is set below 0", async function () {
              //       price = 0 //how to test negative price?!
              //       tokenId = 0
              //       await expect(
              //           NftMarketplace.listItem(nftAddress, tokenId, price, {
              //               value: listFee.toString(),
              //           })
              //       ).to.be.revertedWith("NftMarketplace__PriceMustBeAboveOrEqualZero")
              //   })

              it("does not list if msg.sender is not owner of the NFT", async function () {
                  const accounts = await ethers.getSigners()
                  const accountConnectedNftMarketplace = NftMarketplace.connect(accounts[1])
                  price = 1
                  tokenId = 0
                  await expect(
                      accountConnectedNftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.be.revertedWith("NftMarketplace__NotOwner")
              })

              it("does not list if marketplace contract is not an approved sender", async function () {
                  price = 0
                  tokenId = 0
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.be.revertedWith("NftMarketplace__TransferNotApprovedForMarketplace")
              })

              it("does not list non-existent nfts", async function () {
                  price = 0
                  tokenId = 99
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.be.revertedWith("ERC721: invalid token ID")
              })

              it("updates s_listings with correct parameters", async function () {
                  await basicNFT.approve(NftMarketplace.address, 0)
                  price = 1
                  tokenId = 0
                  await NftMarketplace.listItem(nftAddress, tokenId, price, {
                      value: listFee.toString(),
                  })
                  listingPrice = await NftMarketplace.getListingPrice(nftAddress, tokenId)
                  listingSeller = await NftMarketplace.getListingSeller(nftAddress, tokenId)
                  assert.equal(price.toString(), listingPrice.toString())
                  assert.equal(deployer, listingSeller)
              })

              it("emits an event when item is listed", async function () {
                  await basicNFT.approve(NftMarketplace.address, 0)
                  price = 1
                  tokenId = 0
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.emit(NftMarketplace, "ItemListed")
              })

              it("does not list the same nft twice", async function () {
                  await basicNFT.approve(NftMarketplace.address, 0)
                  price = 1
                  tokenId = 0
                  await NftMarketplace.listItem(nftAddress, tokenId, price, {
                      value: listFee.toString(),
                  })
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.be.revertedWith("NftMarketplace__AlreadyListed")
              })
          })

          describe("buyItem", function () {
              beforeEach(async function () {
                  await basicNFT.approve(NftMarketplace.address, 0)
                  price = 2
                  tokenId = 0
                  await expect(
                      NftMarketplace.listItem(nftAddress, tokenId, price, {
                          value: listFee.toString(),
                      })
                  ).to.emit(NftMarketplace, "ItemListed")
              })
              it("does not buy an unlisted item", async function () {
                  price = await NftMarketplace.getListingPrice(nftAddress, 0)
                  await expect(
                      NftMarketplace.buyItem(nftAddress, 1, { value: price })
                  ).to.be.revertedWith("NftMarketplace__NotListed")
              })
              it("does not buy an item with a value below price", async function () {
                  price = await NftMarketplace.getListingPrice(nftAddress, 0)
                  await expect(
                      NftMarketplace.buyItem(nftAddress, 0, { value: (price - 1).toString() })
                  ).to.be.revertedWith("NftMarketplace__NotEnoughEthToBuy")
              })
          })
      })