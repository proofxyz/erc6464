// SPDX-License-Identifier: MIT
// Copyright 2023 PROOF Holdings Inc
pragma solidity ^0.8.0;

import {IERC6464, IERC6464Events, IERC6464AnyApproval} from "./interfaces/IERC6464.sol";
import {IERC721, ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";

abstract contract ERC6464 is ERC721, IERC6464, IERC6464AnyApproval, IERC6464Events {
    type TokenNonce is uint256;
    type OwnerNonce is uint256;

    /**
     * @notice Thrown if a caller is not authorized (owner or approved) to perform an action.
     */
    error NotAuthorized(address operator, uint256 tokenId);

    /**
     * @notice Nonce used to efficiently revoke all approvals of a tokenId
     */
    mapping(uint256 => TokenNonce) private _tokenNonce;
    /**
     * @notice Nonce used to efficiently revoke all approvals of an Owner
     */
    mapping(address => OwnerNonce) private _ownerNonce;

    /**
     * @dev tokenId -> tokenNonce -> ownerNounce -> operator -> approval
     */
    mapping(uint256 => mapping(TokenNonce => mapping(OwnerNonce => mapping(address => bool)))) private
        _isExplicitlyApprovedFor;

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(address operator, uint256 tokenId, bool approved) public {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NotAuthorized(_msgSender(), tokenId);
        }
        TokenNonce tNonce = _tokenNonce[tokenId];
        OwnerNonce oNonce = _ownerNonce[ownerOf(tokenId)];
        _isExplicitlyApprovedFor[tokenId][tNonce][oNonce][operator] = approved;
        emit ExplicitApprovalFor(operator, tokenId, approved);
    }

    /**
     * @inheritdoc IERC6464
     */
    function setExplicitApproval(address operator, uint256[] calldata tokenIds, bool approved) external {
        for (uint256 id = 0; id < tokenIds.length; id++) {
            setExplicitApproval(operator, tokenIds[id], approved);
        }
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals() external {
        _ownerNonce[_msgSender()] = OwnerNonce.wrap(OwnerNonce.unwrap(_ownerNonce[_msgSender()]) + 1);
        emit AllExplicitApprovalsRevoked(_msgSender());
    }

    /**
     * @inheritdoc IERC6464
     */
    function revokeAllExplicitApprovals(uint256 tokenId) public {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NotAuthorized(_msgSender(), tokenId);
        }
        _revokeAllExplicitApprovals(tokenId);
    }

    /**
     * @inheritdoc IERC6464
     */
    function isExplicitlyApprovedFor(address operator, uint256 tokenId) public view returns (bool) {
        TokenNonce tNonce = _tokenNonce[tokenId];
        OwnerNonce oNonce = _ownerNonce[ownerOf(tokenId)];
        return _isExplicitlyApprovedFor[tokenId][tNonce][oNonce][operator];
    }

    /**
     * @inheritdoc IERC6464AnyApproval
     */
    function isApprovedFor(address operator, uint256 tokenId) public view returns (bool) {
        return isExplicitlyApprovedFor(operator, tokenId) || isApprovedForAll(ownerOf(tokenId), operator)
            || getApproved(tokenId) == operator;
    }

    /**
     * @notice Revoking explicit approvals on token transfer.
     */
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        virtual
        override
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        if (from == address(0)) {
            return;
        }

        for (uint256 i = 0; i < batchSize; i++) {
            _revokeAllExplicitApprovals(firstTokenId + i);
        }
    }

    /**
     * @notice Revokes all explicit approvals for a token.
     */
    function _revokeAllExplicitApprovals(uint256 tokenId) internal {
        _tokenNonce[tokenId] = TokenNonce.wrap(TokenNonce.unwrap(_tokenNonce[tokenId]) + 1);
        emit AllExplicitApprovalsRevoked(ownerOf(tokenId), tokenId);
    }

    /**
     * @notice Overriding OZ's `_isApprovedOrOwner` check to grant for explicit approvals the same permissions as standard
     * ERC721 approvals.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        address owner = ownerOf(tokenId);
        return spender == owner || isApprovedFor(spender, tokenId);
    }

    /**
     * @notice OZ's `approve` does only check for `isApprovedForAll`. Overriding to allow all approvals.
     */
    function approve(address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: approve caller is not token owner or approved");
        _approve(to, tokenId);
    }
}
