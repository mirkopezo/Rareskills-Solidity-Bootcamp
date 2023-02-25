// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC2981} from "openzeppelin/token/common/ERC2981.sol";
import {MerkleProof} from "openzeppelin/utils/cryptography/MerkleProof.sol";

/**
 * @title MyOwnNFTCollection
 * @author Zigtur
 * @notice This smart contract is a NFT collection with optimized MerkleTree and bitmap presale, and royalties
 * @dev Merkle Tree needs to be generated before deploying the contract
 */
contract MyOwnNFTCollection is ERC721, ERC2981 {
    uint256 public constant mintPrice = 0.000001 ether;
    uint256 public constant discountPrice = 0.0000005 ether;
    uint256 public immutable presaleMaxSupply;
    bytes32 private immutable merkleRoot;

    uint256 private constant MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private ticketGroup0 = MAX_INT;
    uint256 private ticketGroup1 = MAX_INT;
    uint256 private ticketGroup2 = MAX_INT;
    uint256 private ticketGroup3 = MAX_INT;
    uint256 private constant MAX_TICKETS = 1000;

    constructor(string memory _name, string memory _symbol, uint256 _presaleMaxSupply, bytes32 _merkleRoot, uint96 ownerRoyaltiesFees) ERC721(_name, _symbol) {
        presaleMaxSupply = _presaleMaxSupply;
        merkleRoot = _merkleRoot;
        _setDefaultRoyalty(msg.sender, ownerRoyaltiesFees);
    }

    /**
     * @notice Mint NFT with price = mintPrice
     * @param _to address Address to which NFT will be minted
     * @param _tokenId uint256 ID of the token to mint
     */
    function mint(address _to, uint256 _tokenId) external payable {
        require(msg.value == mintPrice, "Value is not mintPrice");
        require(_tokenId > 0 && _tokenId <= presaleMaxSupply, "_tokenId is not in range");
        _safeMint(_to, _tokenId);
    }
    
    /**
     * @notice Mint NFT during presale. Valide presale ticket is needed (whitelist)
     * @dev Some assembly code has been used for gas optimization purposes
     * @param _tokenId uint256 ID of the token to mint
     * @param ticket uint256 Presale ticket associated to msg.sender address
     * @param merkleProof bytes32[] Proof used to verify if msg.sender can mint using presale ticket
     */
    function presaleMint(uint256 _tokenId, uint256 ticket, bytes32[] calldata merkleProof) external payable {
        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(msg.sender, ticket))))), "Invalid merkle proof");
        require(ticket <= MAX_TICKETS, "Ticket not in range");
        uint256 ticketGroupValue;
        uint256 ticketSlot;
        uint256 ticketOffset;
        unchecked{
            ticketSlot = ticket / 256;
            ticketOffset = ticket % 256;
        }

        // This assembly code allows us to remove the use of an array, to be more gas efficient during reading !
        assembly {
            ticketSlot := add(ticketGroup0.slot, ticketSlot) // moving to correspond ticketSlot
            ticketGroupValue := sload(ticketSlot)        // load word value from storage to local variable
        }

        uint256 isTicketAvailable = (ticketGroupValue >> ticketOffset) & uint256(1);
        require(isTicketAvailable == 1, "Ticket has already been used");
        ticketGroupValue = ticketGroupValue & ~(uint256(1) << ticketOffset);
        
        // Store the new ticketGroup value in storage
        assembly {
            sstore(ticketSlot, ticketGroupValue)
        }

        require(msg.value == discountPrice, "Value is not discountPrice");
        require(_tokenId > 0 && _tokenId <= presaleMaxSupply, "_tokenId is not in range");
        _safeMint(msg.sender, _tokenId);
    }

    /**
     * @notice Same function as mint(), but using msg.sender as receiver of the minted token
     * @param _tokenId ID of the token to mint
     */
    function selfMint(uint256 _tokenId) external payable {
        require(msg.value == mintPrice, "Value is not mintPrice");
        require(_tokenId > 0 && _tokenId <= presaleMaxSupply, "_tokenId is not in range");
        _safeMint(msg.sender, _tokenId);
    }

    /**
     * @notice Modify a token royalty settings
     * @param _tokenId uint256 ID of the token to which royalty will be changed
     * @param receiver address Address that will receive royalties on sell
     * @param feeNumerator uint96 Amount of royalty, this is divided by 10000 to get a percentage
     */
    function setTokenRoyalty(uint256 _tokenId, address receiver, uint96 feeNumerator) external {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "_msgSender() is not owner or approved");
        _setTokenRoyalty(_tokenId, receiver, feeNumerator);
    }

    /**
     * @notice Standard Interface declaration
     * @dev ERC-165 support
     * @param interfaceId bytes4 The interface identifier, as specified in ERC-165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev baseURI used with tokenURI
     */    
    function _baseURI() internal pure override returns (string memory) {
        return "https://raw.githubusercontent.com/zigtur/Rareskills-Solidity-Bootcamp/master/Week2/nft-collection/";
    }
}
