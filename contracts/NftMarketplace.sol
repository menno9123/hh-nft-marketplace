// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Imports
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error NftMarketplace__NotEnoughEthForListFee();
error NftMarketplace__PriceMustBeAboveOrEqualZero();
error NftMarketplace__TransferNotApprovedForMarkeplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();

contract NftMarketplace {
    /* Type Declarations */
    struct Listing {
        uint256 price;
        address seller;
    }

    /* State Variables */
    uint256 private s_listFee;
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    // something to keep track

    /* Contract Speciic Variables */

    /* Events */
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    /* Constructors */
    constructor(uint256 listFee) {
        s_listFee = listFee;
    }

    /* Modifiers */
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {}
        _;
    }

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketplace__NotOwner();
        }
        _;
    }

    /*
     * @notice Method for listing NFTs on the marketplace
     * @param nftAddress: Address of the NFT to be listed
     * @param tokenId: Token ID of the NFT
     * @param price: sale price of the NFT to be listed
     * @dev This contract implements a marketplace using a
     * mapping without requiring the NFT to be send to the marketplace (not so gas efficient)
     * It uses the ERC721 transfer approval functionaility to transfer the NFT
     * on behalf of the former NFT owner to its new owner
     */

    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        payable
        notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        // check if payment to the platform is sufficient
        if (msg.value < s_listFee) {
            revert NftMarketplace__NotEnoughEthForListFee();
        }
        // check if price is equal or above
        if (price <= 0) {
            revert NftMarketplace__PriceMustBeAboveOrEqualZero();
        }
        // Approve NFT transfer for listed item
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__TransferNotApprovedForMarkeplace();
        }
        // Update listings
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(address nftAddress, uint256 tokenId) external payable {
        //
    }

    function updateListing() public payable {}

    function withdrawProceeds() public {}
}
