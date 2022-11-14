//SPDX-License_Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "hardhat/console.sol";

error RandomIpfsNft__NeedMoreETHSent();
error RandomIpfsNft_AlreadyInitialized();
error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__TransferFailed();

contract RandomIpfsNft is ERC721URIStorage, VRFConsumerBaseV2, Ownable {
    // when we mint an NFT, we will trigger a chainlink VRF call toget us a random
    // number, using this number, we will get a random nft
    // Ex (nfts) : Pug, Shiba Inu, St. Bernard
    //Pug - super rare
    //Shiba sort of rare
    //St. bernard common

    //users have to pay to mint NFT
    //the owner of the contract can withdraw the ETH

    //Types
    enum Breed {
        PUG,
        SHIBA_INU,
        ST_BERNARD
    }

    //chainlink vrf variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callBackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //NFT variables
    uint256 private immutable i_mintFee;
    uint256 private s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal s_dogTokenUris;
    bool private s_initialized;

    //VRF helpers
    mapping(uint256 => address) public s_requestIdToSender;

    //events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(Breed breed, address minter);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, //keyhash
        uint256 mintFee,
        uint32 callBackGasLimit,
        string[3] memory dogTokenUris
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS NFT", "RIN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_mintFee = mintFee;
        i_callBackGasLimit = callBackGasLimit;
        _initializeContract(dogTokenUris);
        s_tokenCounter = 0;
    }

    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < i_mintFee) {
            revert RandomIpfsNft__NeedMoreETHSent();
        }

        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
        );
        //we cant call mint here, caz this function is called bu the user amd
        // then chainlink vrf calls fulfillRandomwords so we need to call mint inside
        // fulfillRandomWords. But again we have one more issue here.
        // if we call mint inside fulfillRandomWords, then mint function needs msg.sender.
        // inside fulfillRandomWords, msg.sender will be chainlink node as it calls the method.
        //So, to access owner/requester inside fulfillRandomWords, we store requester/owner in /mapping using below line. Using this/requestId inside fulfillRandomWords, we can access
        //requester. which can be passed to mint function as msg.sender. Wow!.
        s_requestIdToSender[requestId] = msg.sender;

        emit NftRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address dogOwner = s_requestIdToSender[requestId];
        uint256 newItemId = s_tokenCounter;
        s_tokenCounter = s_tokenCounter + 1;
        //NUM_WORDS = 0 -> so randome number will be randomWords[0]
        uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE; //moduled range
        // modeed Rng will be  -> 0 to 99
        // 7 -> pug -> <10
        // 12 -> shiba inu -> <40
        // 88 -> st. bernard -> >40
        Breed dogBreed = getBreedFromModdedRng(moddedRng);

        _safeMint(dogOwner, newItemId);
        _setTokenURI(newItemId, s_dogTokenUris[uint256(dogBreed)]);
        emit NftMinted(dogBreed, dogOwner);
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 40, MAX_CHANCE_VALUE];
    }

    function _initializeContract(string[3] memory dogTokenUris) private {
        if (s_initialized) {
            revert RandomIpfsNft_AlreadyInitialized();
        }
        s_dogTokenUris = dogTokenUris;
        s_initialized = true;
    }

    function getBreedFromModdedRng(uint256 moddedRng) public pure returns (Breed) {
        uint256 cummulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();

        for (uint256 i = 0; i < chanceArray.length; i++) {
            // PUG = 0 - 9 -> 10% chances
            // Shiba-Inu = 10 - 39 -> 30% chances
            // St. Bernard = 40 - 99 -> 60% chances

            if (moddedRng >= cummulativeSum && moddedRng < chanceArray[i]) {
                return Breed(i);
            }
            cummulativeSum += chanceArray[i];
        }
        revert RandomIpfsNft__RangeOutOfBounds();
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RandomIpfsNft__TransferFailed();
        }
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getDogTokenUris(uint256 index) public view returns (string memory) {
        return s_dogTokenUris[index];
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
