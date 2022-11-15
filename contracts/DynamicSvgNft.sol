//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "base64-sol/base64.sol";
pragma solidity ^0.8.7;

contract DynamicSvgNft is ERC721 {
    // mint
    //store our svg info somewhere
    //some logic to say show x image or show y image

    uint256 private s_tokenCounter = 0;
    string private i_loaImageURI;
    string private i_highImageURI;
    string private constant bbase64EncodedSvgPrefix = "data:image/svg+xml;base64,";

    constructor(string memory lowSvg, string memory highSvg) ERC721("DynamicSvgNft", "DSN") {
        s_tokenCounter = 0;
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        // takes in the svg as input
        // converts svg to base64 string
        // apends it the prefix above using which we can see the fetch.
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(bbase64EncodedSvgPrefix, svgBase64Encoded));
    }

    function mintNft() public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter = s_tokenCounter + 1;
    }
}
