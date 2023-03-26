// SPDX-License-Identifier: MIT
// Copyright 2023 PROOF Holdings Inc
pragma solidity ^0.8.0;

import "./ERC6464.t.sol";

import {ERC6464, ERC721} from "../src/ERC6464.sol";

contract TestableReferenceERC6464 is ERC6464, ITestableERC6464 {
    uint256 private _counter = 0;

    constructor() ERC721("REFERENCE-6464", "R6464") {}

    function mint(address to, uint256 tokenId) external {
        if (_exists(tokenId)) {
            _transfer(ownerOf(tokenId), to, tokenId);
            return;
        }

        _mint(to, tokenId);
    }
}

contract ReferenceERC6464Test is ERC6464Test {
    function _init() internal virtual override returns (ITestableERC6464) {
        return new TestableReferenceERC6464();
    }

    function _unauthorisedERC6464OperatorError(address operator, uint256 tokenId)
        internal
        virtual
        override
        returns (bytes memory)
    {
        return abi.encodeWithSelector(ERC6464.NotAuthorized.selector, operator, tokenId);
    }

    function _unauthorisedERC721TransferError(address, address, address, uint256)
        internal
        virtual
        override
        returns (bytes memory)
    {
        return bytes("ERC721: caller is not token owner or approved");
    }

    function _unauthorisedERC721ApproveError(address, address, uint256)
        internal
        virtual
        override
        returns (bytes memory)
    {
        return "ERC721: approve caller is not token owner or approved";
    }
}

// TODO(Dave): See if we can abstract inheriting the individual test contracts away and wrap this into a convenient test suite.

contract ReferenceSetExplicitApprovalTest is ReferenceERC6464Test, SetExplicitApprovalTest {}

contract ReferenceSetSingleExplicitApprovalTest is ReferenceERC6464Test, SetSingleExplicitApprovalTest {}

contract ReferenceRevokeAllExplicitApprovalsTest is ReferenceERC6464Test, RevokeAllExplicitApprovalsTest {}

contract ReferenceRevokeAllExplicitApprovalsForTokenTest is
    ReferenceERC6464Test,
    RevokeAllExplicitApprovalsForTokenTest
{}

contract ReferenceERC721FeaturesTest is ReferenceERC6464Test, ERC721FeaturesTest {}
