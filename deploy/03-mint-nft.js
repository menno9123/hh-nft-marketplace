const { developmentChains } = require("../helper-hardhat-config")
const { ethers, network } = require("hardhat")

module.exports = async function ({ getNamedAccounts }) {
    const { deployer } = await getNamedAccounts()

    //Mint basic NFT
    const basicNFT = await ethers.getContract("BasicNFT", deployer)
    const basicMintTx = await basicNFT.mintNFT()
    await basicMintTx.wait(1)
    console.log(`Basic NFT index 0 has tokenURI: ${await basicNFT.tokenURI(0)}`)
}
module.exports.tags = ["all", "mint"]
