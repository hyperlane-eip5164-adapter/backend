pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMailbox} from "./interfaces/IMailbox.sol";
import {IInterchainGasPaymaster} from "./interfaces/IInterchainGasPaymaster.sol";
import {TypeCasts} from "./libraries/TypeCasts.sol";
import {Errors} from "./libraries/Errors.sol";
import {IMessageDispatcher} from "./interfaces/EIP5164/IMessageDispatcher.sol";

contract HyperlaneSenderAdapter is Ownable {
    /// @notice `Mailbox` contract reference.
    IMailbox public immutable mailbox;

    /// @notice `IGP` contract reference.
    IInterchainGasPaymaster public igp;

    uint256 public nonce;

    /**
     * @notice Domain identifier for each destination chain.
     * @dev dstChainId => dstDomainId.
     */
    mapping(uint256 => uint32) public destinationDomains;

    /**
     * @notice Emitted when the IGP is set.
     * @param paymaster The new IGP for this adapter.
     */
    event IgpSet(address indexed paymaster);

    /**
     * @notice Domain identifier for each destination chain.
     * @dev dstChainId => dstDomainId.
     */
    mapping(uint256 => uint32) public destinationDomains;

    /**
     * @notice Emitted when a domain identifier for a destination chain is updated.
     * @param dstChainId Destination chain identifier.
     * @param dstDomainId Destination domain identifier.
     */
    event DestinationDomainUpdated(uint256 dstChainId, uint32 dstDomainId);

    /**
     * @notice HyperlaneSenderAdapter constructor.
     * @param _mailbox Address of the Hyperlane `Mailbox` contract.
     */
    constructor(address _mailbox, address _igp) {
        if (_mailbox == address(0)) {
            revert Errors.InvalidMailboxZeroAddress();
        }
        mailbox = IMailbox(_mailbox);
        _setIgp(_igp);
    }

    /**
     * @notice Get new message Id and increment nonce
     * @param _toChainId is the destination chainId.
     * @param _to is the contract address on the destination chain.
     */

    function _getNewMessageId(
        uint256 _toChainId,
        address _to
    ) internal returns (bytes32 messageId) {
        messageId = keccak256(
            abi.encodePacked(
                getChainId(),
                _toChainId,
                nonce,
                address(this),
                _to
            )
        );
        nonce++;
    }

    /// @dev Get current chain id
    function getChainId() public view virtual returns (uint256 cid) {
        assembly {
            cid := chainid()
        }
    }

    /// @dev we narrow mutability (from view to pure) to remove compiler warnings.
    /// @dev unused parameters are added as comments for legibility.
    function getMessageFee(
        uint256 toChainId,
        address,
        /* to*/ bytes calldata /* data*/
    ) external view override returns (uint256) {
        uint32 dstDomainId = _getDestinationDomain(toChainId);
        // destination gasAmount is hardcoded to 500k similar to Wormhole implementation
        // See https://docs.hyperlane.xyz/docs/build-with-hyperlane/guides/paying-for-interchain-gas
        try igp.quoteGasPayment(dstDomainId, 500000) returns (
            uint256 gasQuote
        ) {
            return gasQuote;
        } catch {
            // Default to zero, MultiMessageSender.estimateTotalMessageFee doesn't expect this function to revert
            return 0;
        }
    }

    /**
     * @notice Sets the IGP for this adapter.
     * @dev See _setIgp.
     */
    function setIgp(address _igp) external onlyOwner {
        _setIgp(_igp);
    }

    function dispatchMessage(
        uint256 _toChainId,
        address _to,
        bytes calldata _data
    ) external payable override returns (bytes32) {
        address receiverAdapter = receiverAdapters[_toChainId]; // read value into memory once
        if (receiverAdapter == address(0)) {
            revert Errors.InvalidAdapterZeroAddress();
        }
        bytes32 msgId = _getNewMessageId(_toChainId, _to);
        uint32 dstDomainId = _getDestinationDomain(_toChainId);

        if (dstDomainId == 0) {
            revert Errors.UnknownDomainId(_toChainId);
        }

        bytes32 hyperlaneMsgId = IMailbox(mailbox).dispatch(
            dstDomainId,
            TypeCasts.addressToBytes32(receiverAdapter), //receiver adapter is the reciever
            // Include the source chain id so that the receiver doesn't have to maintain a srcDomainId => srcChainId mapping
            abi.encode(getChainId(), msgId, msg.sender, _to, _data)
        );

        // try to make gas payment, ignore failures
        // destination gasAmount is hardcoded to 500k similar to Wormhole implementation
        // refundAddress is set from MMS caller state variable
        try
            igp.payForGas{value: msg.value}(
                hyperlaneMsgId,
                dstDomainId,
                500000,
                MultiMessageSender(msg.sender).caller()
            )
        {} catch {}

        emit MessageDispatched(msgId, msg.sender, _toChainId, _to, _data);
        return msgId;
    }

    function updateReceiverAdapter(
        uint256[] calldata _dstChainIds,
        address[] calldata _receiverAdapters
    ) external override onlyOwner {
        if (_dstChainIds.length != _receiverAdapters.length) {
            revert Errors.MismatchChainsAdaptersLength(
                _dstChainIds.length,
                _receiverAdapters.length
            );
        }
        for (uint256 i; i < _dstChainIds.length; ++i) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
            emit ReceiverAdapterUpdated(_dstChainIds[i], _receiverAdapters[i]);
        }
    }

    /**
     * @notice Updates destination domain identifiers.
     * @param _dstChainIds Destination chain ids array.
     * @param _dstDomainIds Destination domain ids array.
     */
    function updateDestinationDomainIds(
        uint256[] calldata _dstChainIds,
        uint32[] calldata _dstDomainIds
    ) external onlyOwner {
        if (_dstChainIds.length != _dstDomainIds.length) {
            revert Errors.MismatchChainsDomainsLength(
                _dstChainIds.length,
                _dstDomainIds.length
            );
        }
        for (uint256 i; i < _dstChainIds.length; ++i) {
            destinationDomains[_dstChainIds[i]] = _dstDomainIds[i];
            emit DestinationDomainUpdated(_dstChainIds[i], _dstDomainIds[i]);
        }
    }

    /**
     * @notice Returns destination domain identifier for given destination chain id.
     * @dev dstDomainId is read from destinationDomains mapping
     * @dev Returned dstDomainId can be zero, reverting should be handled by consumers if necessary.
     * @param _dstChainId Destination chain id.
     * @return destination domain identifier.
     */
    function _getDestinationDomain(
        uint256 _dstChainId
    ) internal view returns (uint32) {
        return destinationDomains[_dstChainId];
    }

    /**
     * @dev Sets the IGP for this adapter.
     * @param _igp The IGP contract address.
     */
    function _setIgp(address _igp) internal {
        igp = IInterchainGasPaymaster(_igp);
        emit IgpSet(_igp);
    }
}
