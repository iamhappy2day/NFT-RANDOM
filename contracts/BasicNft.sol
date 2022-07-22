// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    // TODO: add token URI
    string public constant TOKEN_URI = "ipfs://QmfJbeibk2ZLUMSfVvghY1d5P1eYMdeC59KydnCFrMdskB";
    uint256 private s_tokenCounter;

    constructor() ERC721("singleNft", "NftColelction") {
        s_tokenCounter = 0;
    }

    function mintNft() public returns (uint256) {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;
        return s_tokenCounter;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return TOKEN_URI;
    }
}
