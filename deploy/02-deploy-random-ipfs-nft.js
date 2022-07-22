const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { storeImages, storeTokenUriMetadata } = require("../utils/uploadToPinata")
const { verify } = require("../utils/verify")
require("dotenv").config()

// for ipfs
const imagesLocation = "./images/"
const metadataTemplate = {
    name: "",
    description: "",
    image: "",
    attributes: [
        {
            type: "Happiness",
            value: 100,
        },
    ],
}

let tokenUris = [
    "ipfs://QmPA2j7w8MyxfmyPvC7m3wA6mUH7q7CmZLYgPLm1evRbiw",
    "ipfs://QmbJuVBGgPFk2m9pr1GUPCPXo4Lce59AngK3uG6AhZYmtv",
    "ipfs://QmfJbeibk2ZLUMSfVvghY1d5P1eYMdeC59KydnCFrMdskB",
]

const fundAmount = "1000000000000000000000" // 10 link?

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    // get the IPFS hashes of our images
    if (process.env.UPLOAD_TO_PINATA == "true") {
        tokenUris = await handleTokenUris()
    }

    let vrfCoordinatorV2Address, subscriptionId

    if (developmentChains.includes(network.name)) {
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const tx = await vrfCoordinatorV2Mock.createSubscription()
        const txReceipt = await tx.wait(1)
        subscriptionId = txReceipt.events[0].args.subId
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, fundAmount)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2
        subscriptionId = networkConfig[chainId].subscriptionId
    }

    log("___________________________________")

    const args = [
        vrfCoordinatorV2Address,
        subscriptionId,
        networkConfig[chainId].gasLane,
        networkConfig[chainId].mintFee,
        networkConfig[chainId].callbackGasLimit,
        tokenUris,
    ]

    const randomIpfsNft = await deploy("RandomIpfsNft", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("---------------------------------------")

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        console.log("Verifying...")
        await verify(randomIpfsNft.address, args)
    }

    async function handleTokenUris() {
        tokenUris = []
        // store images in IPFS
        // store metadata in IPFS
        const { responses: imageUploadResponses, files } = await storeImages(imagesLocation)
        // console.log("imageUploadResponses", await storeImages(imagesLocation))
        for (imageUploadResponseIndex in imageUploadResponses) {
            // create metadata
            // upload metadata
            let tokenUriMetadata = { ...metadataTemplate }
            tokenUriMetadata.name = files[imageUploadResponseIndex].replace(".png", "")
            tokenUriMetadata.description = `Cute nft of ${tokenUriMetadata.name}`
            tokenUriMetadata.image = `ipgs://${imageUploadResponses[imageUploadResponseIndex].IpfsHash}`
            console.log(`Uplaoding ${tokenUriMetadata.name}...`)
            // store the JSON to pinata / IPFS
            const metadataUploadResponse = await storeTokenUriMetadata(tokenUriMetadata)
            tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`)
        }
        console.log("Token URIS uplaoded! They are:")
        console.log(tokenUris)
        return tokenUris
    }
}

module.exports.tags = ["all", "RandomIpfsNft", "main"]
