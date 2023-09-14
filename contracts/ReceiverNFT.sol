// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {HyperlaneReceiverAdapter} from "./hyperlaneAdapter/HyperlaneReceiverAdapter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import {IMessageExecutor} from "./hyperlaneAdapter/interfaces/EIP5164/IMessageExecutor.sol";
import {IMessageDispatcher} from "./hyperlaneAdapter/interfaces/EIP5164/IMessageDispatcher.sol";
import {TypeCasts} from "./hyperlaneAdapter/libraries/TypeCasts.sol";
import "./IMultiChainNFT.sol";
import {ExecutorAware} from "./hyperlaneAdapter/interfaces/EIP5164/ExecutorAware.sol";

contract ReceiverNFT is IMultiChainNFT, ERC721URIStorage, ExecutorAware {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address collectionOwner;

    event TokenCreated(string ipfsURL, uint256 tokenId);

    event CallMintLocal(
        uint256 tokenId,
        bytes32 messageId,
        uint256 fromChainId,
        address from,
        address executor
    );

    event CallMintAfterBurn(
        uint256 tokenId,
        bytes32 messageId,
        uint256 fromChainId,
        address from,
        address executor
    );

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        collectionOwner = msg.sender;
        _tokenIds.increment();
    }

    function mintLocal(string memory _tokenURI) external returns (uint256) {
        require(isTrustedExecutor(msg.sender), "Greeter/sender-not-executor");
        //require(msg.sender == collectionOwner, "only owner");

        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _tokenIds.increment();

        emit TokenCreated(_tokenURI, newTokenId);
        emit CallMintLocal(
            newTokenId,
            _messageId(),
            _fromChainId(),
            __msgSender(),
            msg.sender
        );
        return newTokenId;
    }

    function mintAfterBurn(bytes memory _payload) external returns (uint256) {
        require(isTrustedExecutor(msg.sender), "Greeter/sender-not-executor");
        (
            uint256 _tokenId,
            address recipient,
            string memory _tokenURI,
            uint256 originalChain,
            address operator
        ) = abi.decode(_payload, (uint256, address, string, uint256, address));

        bytes memory originalData = abi.encode(
            originalChain,
            operator,
            _tokenId
        );
        //Avoids tokenId collisions.
        uint256 newTokenId = uint256(keccak256(originalData));

        _safeMint(recipient, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);

        emit TokenCreated(_tokenURI, newTokenId);
        emit CallMintAfterBurn(
            newTokenId,
            _messageId(),
            _fromChainId(),
            __msgSender(),
            msg.sender
        );
        return newTokenId;
    }

    function addTrustedAdapter(address _receiverAdapter) external {
        require(msg.sender == collectionOwner);
        _addTrustedExecutor(_receiverAdapter);
    }

    function removeTrustedAdapter(address _receiverAdapter) external {
        require(msg.sender == collectionOwner);
        _removeTrustedExecutor(_receiverAdapter);
    }
}
