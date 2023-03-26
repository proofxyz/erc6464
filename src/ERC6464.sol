// SPDX-License-Identifier: MIT
// Copyright 2023 PROOF Holdings Inc
pragma solidity ^0.8.0;
import {IERC6464} from "./interfaces/IERC6464.sol";
import {IERC6464AnyApproval} from "./interfaces/IERC6464.sol";
import {IERC6464Events} from "./interfaces/IERC6464.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";

error NotOwner(address sender, uint256 tokenId);
error NotAuthorized(address operator, uint256 tokenId);

type TokenNonce is uint256;
type OwnerNonce is uint256;

abstract contract ERC6464 is
    ERC721,
    IERC6464,
    IERC6464AnyApproval,
    IERC6464Events
{

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Nonce used to efficiently revoke all approvals of a tokenId
    mapping(uint256 => TokenNonce) private _tokenNonce;
    /// @notice Nonce used to efficiently revoke all approvals of an Owner
    mapping(address => OwnerNonce) private _ownerNonce;

    /// @dev tokenId -> tokenNonce -> ownerNounce -> operator -> approval
    mapping(uint256 => mapping(TokenNonce => mapping(OwnerNonce => mapping(address => bool))))
        private _isExplicitlyApprovedFor;

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(
        address operator,
        uint256 tokenId,
        bool approved
    ) public {
        if (msg.sender != ownerOf(tokenId)) {
            revert NotOwner(msg.sender, tokenId);
        }
        TokenNonce tNonce = _tokenNonce[tokenId];
        OwnerNonce oNonce = _ownerNonce[ownerOf(tokenId)];
        _isExplicitlyApprovedFor[tokenId][tNonce][oNonce][operator] = approved;
        emit ExplicitApprovalFor(operator, tokenId, approved);
    }

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(
        address operator,
        uint256[] calldata tokenIds,
        bool approved
    ) external {
        for (uint256 id = 0; id < tokenIds.length; id++) {
            setExplicitApproval(operator, tokenIds[id], approved);
        }
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals() external {
        _ownerNonce[msg.sender] = OwnerNonce.wrap(
            OwnerNonce.unwrap(_ownerNonce[msg.sender]) + 1
        );
        emit AllExplicitApprovalsRevoked(msg.sender);
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals(uint256 tokenId) public {
        if (
            msg.sender != ownerOf(tokenId) &&
            !isApprovedFor(msg.sender, tokenId)
        ) {
            revert NotAuthorized(msg.sender, tokenId);
        }
        _tokenNonce[tokenId] = TokenNonce.wrap(
            TokenNonce.unwrap(_tokenNonce[tokenId]) + 1
        );
        emit AllExplicitApprovalsRevoked(ownerOf(tokenId), tokenId);
    }

    /**
     * @inheritdoc IERC6464
     */
    function isExplicitlyApprovedFor(address operator, uint256 tokenId)
        public
        view
        returns (bool)
    {
        TokenNonce tNonce = _tokenNonce[tokenId];
        OwnerNonce oNonce = _ownerNonce[ownerOf(tokenId)];
        return _isExplicitlyApprovedFor[tokenId][tNonce][oNonce][operator];
    }

    /**
     * @inheritdoc IERC6464AnyApproval
     */
    function isApprovedFor(address operator, uint256 tokenId)
        public
        view
        returns (bool)
    {
        return
            isExplicitlyApprovedFor(operator, tokenId) ||
            isApprovedForAll(ownerOf(tokenId),operator) ||
            getApproved(tokenId) == operator;
    }
}
