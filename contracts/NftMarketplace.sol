// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Imports
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

error NftMarketplace__NotEnoughEthForListFee();
error NftMarketplace__NotEnoughEthToBuy();
error NftMarketplace__TransferFailed();
error NftMarketplace__PriceMustBeAboveOrEqualZero();
error NftMarketplace__TransferNotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__ZeroBalance();

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
    mapping(address => uint256) private s_balances;

    /* Contract Speciic Variables */

    /* Events */
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemPurchased(
        address seller,
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemUpdated(
        address indexed seller,
        address indexed NftAddress,
        uint256 indexed tokenId,
        uint256 newPrice
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
        if (listing.price <= 0) {
            revert NftMarketplace__NotListed(nftAddress, tokenId);
        }
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

    modifier onlyNonZeroBalance(address balanceowner) {
        if (s_balances[balanceowner] == 0) {
            revert NftMarketplace__ZeroBalance();
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
        if (price < 0) {
            revert NftMarketplace__PriceMustBeAboveOrEqualZero();
        }
        // Approve NFT transfer for listed item
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__TransferNotApprovedForMarketplace();
        }
        // Update listings
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
    {
        uint256 price = s_listings[nftAddress][tokenId].price;
        if (msg.value < price) {
            revert NftMarketplace__NotEnoughEthToBuy();
        }
        // check if msg.value is equal to the price of the NFT AND if NFT is approved for transfer by this contract, otherwise revert with errors
        address seller = s_listings[nftAddress][tokenId].seller;
        // call NFT transfer function
        IERC721 nft = IERC721(nftAddress);
        nft.transferFrom(seller, msg.sender, tokenId);
        // increase owner's balance by msg.value
        s_balances[seller] += msg.value;
        // remove item from s_listings --> how to safely remove item from mapping?

        // emit Item Bought event
        emit ItemPurchased(seller, msg.sender, nftAddress, tokenId, price);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) public isOwner(nftAddress, tokenId, msg.sender) {
        if (newPrice <= 0) {
            revert NftMarketplace__PriceMustBeAboveOrEqualZero();
        }
        s_listings[nftAddress][tokenId] = Listing(newPrice, msg.sender);
        emit ItemUpdated(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() public onlyNonZeroBalance(msg.sender) {
        (bool success, ) = msg.sender.call{value: s_balances[msg.sender]}("");
        if (!success) {
            revert NftMarketplace__TransferFailed();
        }
        s_balances[msg.sender] = 0;
    }

    function getListFee() public view returns (uint256) {
        return s_listFee;
    }

    function getListingPrice(address nftAddress, uint256 tokenId) public view returns (uint256) {
        return s_listings[nftAddress][tokenId].price;
    }

    function getListingSeller(address nftAddress, uint256 tokenId) public view returns (address) {
        return s_listings[nftAddress][tokenId].seller;
    }

    function getSellerBalance(address seller) public view returns (uint256) {
        return s_balances[seller];
    }
}
