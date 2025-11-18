// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    INonFungibleSeaDropTokenUpgradeable
} from "../interfaces/INonFungibleSeaDropTokenUpgradeable.sol";

import {
    ISeaDropUpgradeable
} from "../interfaces/ISeaDropUpgradeable.sol";

import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams,
    SignedMintValidationParams
} from "../lib/SeaDropStructsUpgradeable.sol";

/**
 * @title  MockSeaDropUpgradeable
 * @notice Lightweight mock that stores configuration updates made by an
 *         `ERC721SeaDropUpgradeable` token and exposes helper getters so that
 *         tests can observe the forwarded state. Mint functions simply invoke
 *         the token's `mintSeaDrop` hook without enforcing business logic.
 */
contract MockSeaDropUpgradeable is ISeaDropUpgradeable {
    /// @notice Track the public drop configuration per nft contract.
    mapping(address => PublicDrop) private _publicDrops;

    /// @notice Track the allow list data per nft contract.
    struct AllowListState {
        bytes32 merkleRoot;
        string allowListURI;
        uint256 publicKeyURICount;
    }
    mapping(address => AllowListState) private _allowLists;

    /// @notice Track token gated drop stages per nft contract.
    mapping(address => mapping(address => TokenGatedDropStage))
        private _tokenGatedDrops;
    mapping(address => address[]) private _tokenGatedTokens;

    /// @notice Track creator payout addresses per nft contract.
    mapping(address => address) private _creatorPayoutAddresses;

    /// @notice Track drop URIs per nft contract.
    mapping(address => string) private _dropURIs;

    /// @notice Track allowed fee recipients per nft contract.
    mapping(address => mapping(address => bool)) private _allowedFeeRecipients;
    mapping(address => address[]) private _enumeratedFeeRecipients;

    /// @notice Track server-side signer params per nft contract.
    mapping(address => mapping(address => SignedMintValidationParams))
        private _signedMintValidationParams;
    mapping(address => address[]) private _enumeratedSigners;

    /// @notice Track payer permissions per nft contract.
    mapping(address => mapping(address => bool)) private _allowedPayers;
    mapping(address => address[]) private _enumeratedPayers;

    /// @notice Track token gated redemption status.
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _tokenGatedRedeemed;

    event MockMinted(
        address indexed nftContract,
        address indexed minter,
        uint256 quantity
    );

    /*//////////////////////////////////////////////////////////////
                        Minting entry points
    //////////////////////////////////////////////////////////////*/

    function mintPublic(
        address nftContract,
        address,
        address minterIfNotPayer,
        uint256 quantity
    ) external payable override {
        address minter = minterIfNotPayer == address(0)
            ? msg.sender
            : minterIfNotPayer;

        INonFungibleSeaDropTokenUpgradeable(nftContract).mintSeaDrop(
            minter,
            quantity
        );
        emit MockMinted(nftContract, minter, quantity);
    }

    function mintAllowList(
        address,
        address,
        address,
        uint256,
        MintParams calldata,
        bytes32[] calldata
    ) external payable override {
        revert("UNIMPLEMENTED");
    }

    function mintSigned(
        address,
        address,
        address,
        uint256,
        MintParams calldata,
        uint256,
        bytes calldata
    ) external payable override {
        revert("UNIMPLEMENTED");
    }

    function mintAllowedTokenHolder(
        address nftContract,
        address,
        address minterIfNotPayer,
        TokenGatedMintParams calldata mintParams
    ) external payable override {
        address minter = minterIfNotPayer == address(0)
            ? msg.sender
            : minterIfNotPayer;

        for (uint256 i = 0; i < mintParams.allowedNftTokenIds.length; ) {
            _tokenGatedRedeemed[nftContract][mintParams.allowedNftToken][
                mintParams.allowedNftTokenIds[i]
            ] = true;
            unchecked {
                ++i;
            }
        }

        INonFungibleSeaDropTokenUpgradeable(nftContract).mintSeaDrop(
            minter,
            mintParams.allowedNftTokenIds.length
        );
        emit MockMinted(
            nftContract,
            minter,
            mintParams.allowedNftTokenIds.length
        );
    }

    /*//////////////////////////////////////////////////////////////
                          View helper methods
    //////////////////////////////////////////////////////////////*/

    function getPublicDrop(address nftContract)
        external
        view
        override
        returns (PublicDrop memory)
    {
        return _publicDrops[nftContract];
    }

    function getCreatorPayoutAddress(address nftContract)
        external
        view
        override
        returns (address)
    {
        return _creatorPayoutAddresses[nftContract];
    }

    function getAllowListMerkleRoot(address nftContract)
        external
        view
        override
        returns (bytes32)
    {
        return _allowLists[nftContract].merkleRoot;
    }

    function getFeeRecipientIsAllowed(address nftContract, address feeRecipient)
        external
        view
        override
        returns (bool)
    {
        return _allowedFeeRecipients[nftContract][feeRecipient];
    }

    function getAllowedFeeRecipients(address nftContract)
        external
        view
        override
        returns (address[] memory)
    {
        return _enumeratedFeeRecipients[nftContract];
    }

    function getSigners(address nftContract)
        external
        view
        override
        returns (address[] memory)
    {
        return _enumeratedSigners[nftContract];
    }

    function getSignedMintValidationParams(
        address nftContract,
        address signer
    ) external view override returns (SignedMintValidationParams memory) {
        return _signedMintValidationParams[nftContract][signer];
    }

    function getPayers(address nftContract)
        external
        view
        override
        returns (address[] memory)
    {
        return _enumeratedPayers[nftContract];
    }

    function getPayerIsAllowed(address nftContract, address payer)
        external
        view
        override
        returns (bool)
    {
        return _allowedPayers[nftContract][payer];
    }

    function getTokenGatedAllowedTokens(address nftContract)
        external
        view
        override
        returns (address[] memory)
    {
        return _tokenGatedTokens[nftContract];
    }

    function getTokenGatedDrop(address nftContract, address allowedNftToken)
        external
        view
        override
        returns (TokenGatedDropStage memory)
    {
        return _tokenGatedDrops[nftContract][allowedNftToken];
    }

    function getAllowedNftTokenIdIsRedeemed(
        address nftContract,
        address allowedNftToken,
        uint256 allowedNftTokenId
    ) external view override returns (bool) {
        return
            _tokenGatedRedeemed[nftContract][allowedNftToken][
                allowedNftTokenId
            ];
    }

    /*//////////////////////////////////////////////////////////////
                       Update forwarding methods
    //////////////////////////////////////////////////////////////*/

    function updateDropURI(string calldata dropURI) external override {
        _dropURIs[msg.sender] = dropURI;
    }

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
    {
        _publicDrops[msg.sender] = publicDrop;
    }

    function updateAllowList(AllowListData calldata allowListData)
        external
        override
    {
        _allowLists[msg.sender] = AllowListState({
            merkleRoot: allowListData.merkleRoot,
            allowListURI: allowListData.allowListURI,
            publicKeyURICount: allowListData.publicKeyURIs.length
        });
    }

    function updateTokenGatedDrop(
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external override {
        if (dropStage.maxTotalMintableByWallet == 0) {
            delete _tokenGatedDrops[msg.sender][allowedNftToken];
            _removeAddress(allowedNftToken, _tokenGatedTokens[msg.sender]);
            return;
        }

        if (_tokenGatedDrops[msg.sender][allowedNftToken].maxTotalMintableByWallet == 0) {
            _tokenGatedTokens[msg.sender].push(allowedNftToken);
        }
        _tokenGatedDrops[msg.sender][allowedNftToken] = dropStage;
    }

    function updateCreatorPayoutAddress(address payoutAddress)
        external
        override
    {
        _creatorPayoutAddresses[msg.sender] = payoutAddress;
    }

    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external
        override
    {
        if (allowed && !_allowedFeeRecipients[msg.sender][feeRecipient]) {
            _allowedFeeRecipients[msg.sender][feeRecipient] = true;
            _enumeratedFeeRecipients[msg.sender].push(feeRecipient);
        } else if (
            !allowed && _allowedFeeRecipients[msg.sender][feeRecipient]
        ) {
            _allowedFeeRecipients[msg.sender][feeRecipient] = false;
            _removeAddress(feeRecipient, _enumeratedFeeRecipients[msg.sender]);
        }
    }

    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams
    ) external override {
        if (
            _signedMintValidationParams[msg.sender][signer].maxMaxTotalMintableByWallet ==
            0
        ) {
            _enumeratedSigners[msg.sender].push(signer);
        }
        _signedMintValidationParams[msg.sender][
            signer
        ] = signedMintValidationParams;
    }

    function updatePayer(address payer, bool allowed) external override {
        if (allowed && !_allowedPayers[msg.sender][payer]) {
            _allowedPayers[msg.sender][payer] = true;
            _enumeratedPayers[msg.sender].push(payer);
        } else if (!allowed && _allowedPayers[msg.sender][payer]) {
            _allowedPayers[msg.sender][payer] = false;
            _removeAddress(payer, _enumeratedPayers[msg.sender]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                               Helpers
    //////////////////////////////////////////////////////////////*/

    function dropURI(address nftContract) external view returns (string memory) {
        return _dropURIs[nftContract];
    }

    function allowListState(address nftContract)
        external
        view
        returns (AllowListState memory)
    {
        return _allowLists[nftContract];
    }

    function _removeAddress(address target, address[] storage list) private {
        uint256 length = list.length;
        for (uint256 i = 0; i < length; ) {
            if (list[i] == target) {
                list[i] = list[length - 1];
                list.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }
}
