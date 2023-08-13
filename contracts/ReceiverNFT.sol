pragma solidity 0.8.17;

import {HyperlaneReceiverAdapter} from "./hyperlaneAdapter/HyperlaneReceiverAdapter.sol";


contract ReceiverNFT is ERC721URIStorage, HyperlaneSenderAdapter{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 public collectionRoyalty;
    address collectionOwner;

    event TokenCreated(
    string ipfsURL,
    uint256 tokenId
    );

}