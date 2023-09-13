// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {HyperlaneSenderAdapter} from "./hyperlaneAdapter/HyperlaneSenderAdapter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IMessageExecutor} from "./hyperlaneAdapter/interfaces/EIP5164/IMessageExecutor.sol";
import {IMessageDispatcher} from "./hyperlaneAdapter/interfaces/EIP5164/IMessageDispatcher.sol";
import {TypeCasts} from "./hyperlaneAdapter/libraries/TypeCasts.sol";
import "./IMultiChainNFT.sol";

contract SenderNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address collectionOwner;

    event TokenCreated(string ipfsURL, uint256 tokenId);

    IMessageDispatcher senderAdapter;

    constructor(
        string memory _name,
        string memory _symbol,
        address _senderAdapter
    ) ERC721(_name, _symbol) {
        collectionOwner = msg.sender;
        senderAdapter = IMessageDispatcher(_senderAdapter);
        _tokenIds.increment();
    }

    function mintLocal(string memory _tokenURI) external returns (uint256) {
        require(msg.sender == collectionOwner, "only owner");

        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();

        emit TokenCreated(_tokenURI, newTokenId);
        return newTokenId;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorage) {
        super._burn(tokenId);
    }

    /// @notice function to generate a cross-chain NFT transfer request.
    /// @param destChainId chain ID of the destination chain in string.
    /// @param _tokenId nft token ID.
    /// @param _recipient recipient of token ID on destination chain.
    function transferRemote(
        uint256 destChainId,
        uint256 _tokenId,
        address _recipient
    ) public payable {
        require(_ownerOf(_tokenId) == msg.sender, "caller is not the owner");
        require(_exists(_tokenId), "tokenID: inexistent");
        string memory _tokenURI = super.tokenURI(_tokenId);
        _burn(_tokenId);
        uint256 originalChain = getChainId();

        bytes memory payload = abi.encode(
            _tokenId,
            _recipient,
            _tokenURI,
            originalChain,
            address(this)
        );

        // Encode the function call.
        bytes memory targetData = abi.encodeCall(
            IMultiChainNFT.mintAfterBurn,
            payload
        );

        senderAdapter.dispatchMessage(destChainId, _recipient, targetData);
    }

    function mintRemote(
        uint256 _toChainId,
        address _to,
        string memory _tokenURI
    ) external payable {
        // Encode the function call.
        bytes memory targetData = abi.encodeCall(
            IMultiChainNFT.mintLocal,
            _tokenURI
        );

        senderAdapter.dispatchMessage(_toChainId, _to, targetData);
    }

    /// @dev Get current chain id
    function getChainId() public view virtual returns (uint256 cid) {
        assembly {
            cid := chainid()
        }
    }
}
