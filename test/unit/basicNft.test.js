const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Unit tests for basic nft contract", async () => {
          let deployer, basicNftContract

          beforeEach(async () => {
              let accounts = await ethers.getSigners()
              deployer = accounts[0]
              await deployments.fixture(["basicnft"])
              basicNftContract = await ethers.getContract("BasicNft")
          })
          it("Test 1", async () => {
              const tx = await basicNftContract.mintNft()
              await tx.wait(1)
              const tokenCounter = await basicNftContract.getTokenCounter()
              const tokenURI = await basicNftContract.tokenURI(0)

              assert.equal(tokenCounter.toString(), "1")
              assert.equal(tokenURI, await basicNftContract.tokenURI(0))
          })
      })
