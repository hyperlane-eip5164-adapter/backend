// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMailbox} from "./interfaces/IMailbox.sol";
import {IMessageRecipient} from "./interfaces/IMessageRecipient.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "./interfaces/IInterchainSecurityModule.sol";
import {TypeCasts} from "./libraries/TypeCasts.sol";
import {Errors} from "./libraries/Errors.sol";

import {IMessageDispatcher} from "./interfaces/EIP5164/IMessageDispatcher.sol";
import {IMessageExecutor} from "./interfaces/EIP5164/IMessageExecutor.sol";

import "./libraries/MessageStruct.sol";

/**
 * @title HyperlaneReceiverAdapter implementation.
 * @notice `IBridgeReceiverAdapter` implementation that uses Hyperlane as the bridge.
 */
contract HyperlaneReceiverAdapter is
    IMessageExecutor,
    IMessageRecipient,
    ISpecifiesInterchainSecurityModule,
    Ownable
{
    /// @notice `Mailbox` contract reference.
    IMailbox public immutable mailbox;

    /// @notice `ISM` contract reference.
    IInterchainSecurityModule public ism;

    /**
     * @notice Sender adapter address for each source chain.
     * @dev srcChainId => senderAdapter address.
     */
    mapping(uint256 => IMessageDispatcher) public senderAdapters;

    /**
     * @notice Ensure that messages cannot be replayed once they have been executed.
     * @dev msgId => isExecuted.
     */
    mapping(bytes32 => bool) public executedMessages;

    /**
     * @notice Emitted when the ISM is set.
     * @param module The new ISM for this adapter/recipient.
     */
    event IsmSet(address indexed module);

    /**
     * @notice Emitted when a sender adapter for a source chain is updated.
     * @param srcChainId Source chain identifier.
     * @param senderAdapter Address of the sender adapter.
     */
    event SenderAdapterUpdated(uint256 srcChainId, IMessageDispatcher senderAdapter);

    /* Constructor */
    /**
     * @notice HyperlaneReceiverAdapter constructor.
     * @param _mailbox Address of the Hyperlane `Mailbox` contract.
     */
    constructor(address _mailbox) {
        if (_mailbox == address(0)) {
            revert Errors.InvalidMailboxZeroAddress();
        }
        mailbox = IMailbox(_mailbox);
    }

    /// @notice Restrict access to trusted `Mailbox` contract.
    modifier onlyMailbox() {
        if (msg.sender != address(mailbox)) {
            revert Errors.UnauthorizedMailbox(msg.sender);
        }
        _;
    }

    /// @inheritdoc ISpecifiesInterchainSecurityModule
    function interchainSecurityModule()
        external
        view
        returns (IInterchainSecurityModule)
    {
        return ism;
    }

    /**
     * @notice Sets the ISM for this adapter/recipient.
     * @param _ism The ISM contract address.
     */
    function setIsm(address _ism) external onlyOwner {
        ism = IInterchainSecurityModule(_ism);
        emit IsmSet(_ism);
    }

    function executeMessage(
        address _to,
        bytes memory message,
        bytes32 messageId,
        uint256 fromChainId,
        address from
    ) public {
        (bool success, bytes memory returnData) = _to.call(
            abi.encodePacked(message, messageId, fromChainId, from)
        );

        if (!success) {
            revert MessageFailure(messageId, returnData);
        }

        emit MessageIdExecuted(fromChainId, messageId);
    }

    /**
     * @notice Called by Hyperlane `Mailbox` contract on destination chain to receive cross-chain messages.
     * @dev _origin Source chain domain identifier (not currently used).
     * @param _sender Address of the sender on the source chain.
     * @param _body Body of the message.
     */
    function handle(
        uint32,
        /* _origin*/ bytes32 _sender,
        bytes memory _body
    ) external virtual override onlyMailbox {
        // address adapter = TypeCasts.bytes32ToAddress(_sender);
        // (
        //     uint256 srcChainId,
        //     bytes32 msgId,
        //     address srcSender,
        //     address destReceiver,
        //     bytes memory data
        // ) = abi.decode(_body, (uint256, bytes32, address, address, bytes));

        address adapter = TypeCasts.bytes32ToAddress(_sender);
        //IMessageDispatcher adapter = IMessageDispatcher(senderAdapter);
        (
            address destReceiver,
            bytes memory data,
            bytes32 msgId,
            uint256 srcChainId,
            address srcSender
        ) = abi.decode(_body, (address, bytes, bytes32, uint256, address));

        if (IMessageDispatcher(adapter) != senderAdapters[srcChainId]) {
            revert Errors.UnauthorizedAdapter(srcChainId, adapter);
        }
        if (executedMessages[msgId]) {
            revert MessageIdAlreadyExecuted(msgId);
        } else {
            executedMessages[msgId] = true;
        }

        executeMessage(destReceiver, data, msgId, srcChainId, srcSender);
    }

    function updateSenderAdapter(
        uint256[] calldata _srcChainIds,
        IMessageDispatcher[] calldata _senderAdapters
    ) external onlyOwner {
        if (_srcChainIds.length != _senderAdapters.length) {
            revert Errors.MismatchChainsAdaptersLength(
                _srcChainIds.length,
                _senderAdapters.length
            );
        }
        for (uint256 i; i < _srcChainIds.length; ++i) {
            senderAdapters[_srcChainIds[i]] = _senderAdapters[i];
            emit SenderAdapterUpdated(_srcChainIds[i], _senderAdapters[i]);
        }
    }

    function getSenderAdapter(
        uint256 _srcChainId
    ) public view returns (IMessageDispatcher _senderAdapter) {
        _senderAdapter = senderAdapters[_srcChainId];
    }
}
