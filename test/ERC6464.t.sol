// SPDX-License-Identifier: MIT
// Copyright 2023 PROOF Holdings Inc
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC6464} from "../src/ERC6464.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC6464Events, IERC6464, IERC6464AnyApproval} from "../src/interfaces/IERC6464.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

interface ITestableReferenceERC6464 is IERC6464, IERC6464AnyApproval {
    function mint(address _receiver) external;
}

contract TestableReferenceERC6464 is ERC6464, ITestableReferenceERC6464 {
    uint256 counter = 0;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function mint(address _receiver) external {
        _mint(_receiver, counter);
        counter++;
    }

    function _transfer(address from, address to, uint256 id) internal override {
        revokeAllExplicitApprovals(id);
        super._transfer(from, to, id);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
        require(
            isExplicitlyApprovedFor(msg.sender, tokenId) || _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );

        _transfer(from, to, tokenId);
    }
}

contract ERC6464Test is Test, IERC6464Events {
    ITestableReferenceERC6464 public erc6464;
    uint256[] public tokens;

    struct ExplicitApprovalTest {
        address owner;
        address operator;
        bool approve;
        uint256 tokenId;
    }

    constructor(ITestableReferenceERC6464 _erc6464) {
        erc6464 = _erc6464;
    }

    function _testSetExplicitApproval(ExplicitApprovalTest memory _testValues) public {
        for (uint256 i = 0; i <= _testValues.tokenId; i++) {
            erc6464.mint(_testValues.owner);
            tokens.push(i);
        }
        /// @dev even if it's an array will always revert on the first call
        vm.expectRevert(abi.encodeWithSignature("NotOwner(address,uint256)", _testValues.operator, 0));
        vm.prank(_testValues.operator);
        if (_testValues.tokenId < 1) {
            erc6464.setExplicitApproval(_testValues.operator, _testValues.tokenId, _testValues.approve);
        } else {
            erc6464.setExplicitApproval(_testValues.operator, tokens, _testValues.approve);
        }

        vm.startPrank(_testValues.owner);
        vm.expectEmit(true, true, true, true);
        emit ExplicitApprovalFor(_testValues.operator, _testValues.tokenId, _testValues.approve);
        if (_testValues.tokenId < 1) {
            erc6464.setExplicitApproval(_testValues.operator, _testValues.tokenId, _testValues.approve);
        } else {
            erc6464.setExplicitApproval(_testValues.operator, tokens, _testValues.approve);
        }

        assertEq(erc6464.isExplicitlyApprovedFor(_testValues.operator, _testValues.tokenId), _testValues.approve);
        assertEq(erc6464.isApprovedFor(_testValues.operator, _testValues.tokenId), _testValues.approve);

        /// @dev test revokeAllExplicitApprovals
        vm.expectEmit(true, true, true, true);
        emit AllExplicitApprovalsRevoked(_testValues.owner);
        erc6464.revokeAllExplicitApprovals();
        assert(!erc6464.isExplicitlyApprovedFor(_testValues.operator, _testValues.tokenId));
        vm.stopPrank();

        /// @dev test revokeAllExplicitApprovals of id
        vm.expectRevert(
            abi.encodeWithSignature("NotAuthorized(address,uint256)", _testValues.operator, _testValues.tokenId)
        );
        vm.prank(_testValues.operator);
        erc6464.revokeAllExplicitApprovals(_testValues.tokenId);
        vm.startPrank(_testValues.owner);
        erc6464.setExplicitApproval(_testValues.operator, _testValues.tokenId, _testValues.approve);
        vm.expectEmit(true, true, true, true);
        emit AllExplicitApprovalsRevoked(_testValues.owner, _testValues.tokenId);
        erc6464.revokeAllExplicitApprovals(_testValues.tokenId);
        assert(!erc6464.isExplicitlyApprovedFor(_testValues.operator, _testValues.tokenId));

        if (_testValues.tokenId > 1) {
            erc6464.setExplicitApproval(_testValues.operator, tokens, _testValues.approve);
            erc6464.revokeAllExplicitApprovals(_testValues.tokenId);
            assertEq(erc6464.isExplicitlyApprovedFor(_testValues.operator, 0), _testValues.approve);
            vm.stopPrank();

            /// @dev test revoke on transfer
            if (_testValues.approve) {
                console2.log(erc6464.isApprovedFor(_testValues.operator, 0));
                vm.prank(_testValues.operator);
                erc6464.transferFrom(_testValues.owner, _testValues.operator, 0);
                assert(!erc6464.isExplicitlyApprovedFor(_testValues.operator, 0));
                assert(!erc6464.isApprovedFor(_testValues.operator, 0));
            }
        }
    }

    function testExplicitApproval(address _owner, address _operator, bool _approve) public {
        vm.assume(_owner != address(0));
        vm.assume(_operator != address(0));
        vm.assume(_owner != _operator);
        _testSetExplicitApproval(ExplicitApprovalTest(_owner, _operator, _approve, 0));
    }

    function testMultipleExplicitApprovals(address _owner, address _operator, bool _approve, uint256 _tokenId) public {
        vm.assume(_tokenId < 9999);
        vm.assume(_owner != address(0));
        vm.assume(_operator != address(0));
        vm.assume(_owner != _operator);
        _testSetExplicitApproval(ExplicitApprovalTest(_owner, _operator, _approve, _tokenId));
    }
}

contract ReferenceERC6464Test is ERC6464Test {
    constructor() ERC6464Test(new TestableReferenceERC6464("Non Fungible Token", "NFT")) {}
}
