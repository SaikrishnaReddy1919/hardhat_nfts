const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const fs = require("fs")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const chainId = network.config.chainId
    let etheUsdPriceFeedAddress

    if (developmentChains.includes(network.name)) {
        const EthUsdAggregator = await ethers.getContract("MockV3Aggregator")
        etheUsdPriceFeedAddress = EthUsdAggregator.address
    } else {
        etheUsdPriceFeedAddress = networkConfig[chainId].ethUsdPriceFeed
    }

    const lowSvg = await fs.readFileSync("./images/dynamicNft/frown.svg", { encoding: "utf8" })
    const highSvg = await fs.readFileSync("./images/dynamicNft/happy.svg", { encoding: "utf8" })

    const args = [lowSvg, highSvg, etheUsdPriceFeedAddress]

    const dynamicNftContract = await deploy("DynamicSvgNft", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(dynamicNftContract.address, args)
    }
}

module.exports.tags = ["all", "dynamicsvg", "main"]
