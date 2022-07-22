// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// it has already inheritance from ERC721 and it has usefull  func _setTokenURI
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__NeedMoreEthToSend();
error RandomIpfsNft__WihdrawFailed();

pragma solidity ^0.8.7;

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    // when we mint nft we will trigger Chainlink VRF call to get us a random number
    // using that number we will get a random NFT ( 3 types with different rarity)
    // users have to pay to mint NFT
    // the owner of the contract can withdraw the ETH

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_mintFee;

    // VRF helpers
    mapping(uint256 => address) public s_requestIdToSender;

    // Nft variables
    uint256 private s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    // list of urls (uris)
    string[] internal s_nftUris;
    enum NftRange {
        common,
        rare,
        superRare
    }

    // Events
    event NftRequested(uint256 indexed requestid, address requester);
    event NftMinted(NftRange nftRank, address minter);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 mintFee,
        uint32 callbackGasLimit,
        string[] memory nftUris
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("RandomNft", "RNFT") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_mintFee = mintFee;
        i_callbackGasLimit = callbackGasLimit;
        s_tokenCounter = 0;
        s_nftUris = nftUris;
    }

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < i_mintFee) {
            revert RandomIpfsNft__NeedMoreEthToSend();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__WihdrawFailed();
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address nftOwner = s_requestIdToSender[requestId];
        uint256 newTokenId = s_tokenCounter;
        // this one always returns a value between 0 - 99;
        // if it would be value from 0-10 it would be the most rarible nft (10% chance)
        // between 10 and 30 the second one (20% chance)
        // between 30 and max value the less rarible (70% chance)
        uint256 nftChanceValue = randomWords[0] % MAX_CHANCE_VALUE;
        NftRange nftRank = getRarityFromNftRange(nftChanceValue);
        s_tokenCounter++;
        _safeMint(nftOwner, newTokenId);
        _setTokenURI(newTokenId, s_nftUris[uint256(nftRank)]);
        emit NftMinted(nftRank, nftOwner);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {}

    function getRarityFromNftRange(uint256 nftChanceValue) public pure returns (NftRange) {
        uint256 cummulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (nftChanceValue >= cummulativeSum && nftChanceValue <= chanceArray[i]) {
                return NftRange(i);
            }
            cummulativeSum += chanceArray[i];
        }
        // in case we don't return anything
        revert RandomIpfsNft__RangeOutOfBounds();
    }

    // to make rarity we need array of chances for each rarity type
    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getNftUri(uint256 index) public view returns (string memory) {
        return s_nftUris[index];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
