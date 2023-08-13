pragma solidity 0.8.17;

import {HyperlaneSenderAdapter} from "./hyperlaneAdapter/HyperlaneSenderAdapter.sol";

contract SenderNFT is ERC721URIStorage, HyperlaneSenderAdapter {
   
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 public collectionRoyalty;
    address collectionOwner;

    event TokenCreated(string ipfsURL, uint256 tokenId);

    // transfer params struct where we specify which NFTs should be transferred to
    // the destination chain and to which address

    struct TransferParams {
        uint256 nftId;
        bytes recipient;
        string uri;
    }

    

}
