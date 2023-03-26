// SPDX-License-Identifier: MIT
// Copyright 2023 PROOF Holdings Inc
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {IERC6464Events, IERC6464, IERC6464AnyApproval} from "../src/interfaces/IERC6464.sol";

interface ITestableERC6464 is IERC6464, IERC6464AnyApproval {
    function mint(address owner, uint256 tokenId) external;
}

abstract contract ERC6464Test is Test, IERC6464Events {
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    ITestableERC6464 public erc6464;

    function setUp() public virtual {
        erc6464 = _init();
    }

    function _init() internal virtual returns (ITestableERC6464);

    function _unauthorisedERC6464OperatorError(address operator, uint256 tokenId)
        internal
        virtual
        returns (bytes memory);

    function _unauthorisedERC721TransferError(address operator, address from, address to, uint256 tokenId)
        internal
        virtual
        returns (bytes memory);

    function _unauthorisedERC721ApproveError(address operator, address newOperator, uint256 tokenId)
        internal
        virtual
        returns (bytes memory);

    //--------------------------------------------------------------------------
    //                              Assertions
    //--------------------------------------------------------------------------

    mapping(address operator => mapping(uint256 tokenId => bool))[] private _explicitApprovalsBefore;

    modifier assertExplicitApprovalUnchanged(address operator, uint256[] memory tokenIds) {
        mapping(uint256 => bool) storage approvalsBefore = _explicitApprovalsBefore.push()[operator];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            approvalsBefore[tokenIds[i]] = erc6464.isExplicitlyApprovedFor(operator, tokenIds[i]);
        }
        _;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(erc6464.isExplicitlyApprovedFor(operator, tokenIds[i]), approvalsBefore[tokenIds[i]]);
        }
    }

    modifier assertExplicitApproval(address operator, uint256[] memory tokenIds, bool approved, bytes memory err) {
        mapping(uint256 => bool) storage approvalsBefore = _explicitApprovalsBefore.push()[operator];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            approvalsBefore[tokenIds[i]] = erc6464.isExplicitlyApprovedFor(operator, tokenIds[i]);
        }
        _;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(
                erc6464.isExplicitlyApprovedFor(operator, tokenIds[i]),
                err.length > 0 ? approvalsBefore[tokenIds[i]] : approved
            );
        }
    }

    struct ApprovalsAssertion {
        address[] operators;
        uint256[] tokenIds;
        bool approved;
        bool fails;
    }

    modifier assertExplicitApprovals(ApprovalsAssertion memory params) {
        mapping(address => mapping(uint256 => bool)) storage approvalsBefore = _explicitApprovalsBefore.push();
        for (uint256 j = 0; j < params.operators.length; j++) {
            for (uint256 i = 0; i < params.tokenIds.length; i++) {
                approvalsBefore[params.operators[j]][params.tokenIds[i]] =
                    erc6464.isExplicitlyApprovedFor(params.operators[j], params.tokenIds[i]);
            }
        }
        _;
        for (uint256 j = 0; j < params.operators.length; j++) {
            for (uint256 i = 0; i < params.tokenIds.length; i++) {
                assertEq(
                    erc6464.isExplicitlyApprovedFor(params.operators[j], params.tokenIds[i]),
                    params.fails ? approvalsBefore[params.operators[j]][params.tokenIds[i]] : params.approved
                );
            }
        }
    }

    //--------------------------------------------------------------------------
    //                              Helpers
    //--------------------------------------------------------------------------

    function _assumeERC721Receiver(address to) internal view {
        vm.assume(uint160(to) > 10);
        vm.assume(!to.isContract());
    }

    function _mint(address owner, uint256 tokenId) internal {
        _assumeERC721Receiver(owner);
        erc6464.mint(owner, tokenId);
    }

    function _mint(address owner, uint256[] memory tokenIds) internal {
        _assumeERC721Receiver(owner);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            erc6464.mint(owner, tokenIds[i]);
        }
    }

    EnumerableSet.UintSet[] internal _sets;

    function difference(uint256[] memory values, uint256[] memory remove) internal returns (uint256[] memory) {
        EnumerableSet.UintSet storage set = _sets.push();

        for (uint256 i = 0; i < values.length; i++) {
            set.add(values[i]);
        }
        for (uint256 i = 0; i < remove.length; i++) {
            set.remove(remove[i]);
        }
        return set.values();
    }

    function toUint256s(uint256[1] memory input) internal pure returns (uint256[] memory output) {
        output = new uint256[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function toUint256s(uint256[2] memory input) internal pure returns (uint256[] memory output) {
        output = new uint256[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function toUint256s(uint256[3] memory input) internal pure returns (uint256[] memory output) {
        output = new uint256[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function toUint256s(uint256[10] memory input) internal pure returns (uint256[] memory output) {
        output = new uint256[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }

    function toAddresses(address[5] memory input) internal pure returns (address[] memory output) {
        output = new address[](input.length);
        for (uint256 i = 0; i < input.length; i++) {
            output[i] = input[i];
        }
    }
}

abstract contract SetExplicitApprovalTest is ERC6464Test {
    struct TestCase {
        address owner;
        uint256[] ownedTokens;
        address caller;
        address operator;
        uint256[] tokenIds;
        bool approve;
    }

    function _setExplicitApproval(TestCase memory tt, bytes memory err) internal virtual {
        bool fail = err.length > 0;
        if (fail) {
            vm.expectRevert(err);
        } else {
            for (uint256 i = 0; i < tt.tokenIds.length; i++) {
                vm.expectEmit(true, true, true, true, address(erc6464));
                emit IERC6464Events.ExplicitApprovalFor(tt.operator, tt.tokenIds[i], tt.approve);
            }
        }
        vm.prank(tt.caller);
        erc6464.setExplicitApproval(tt.operator, tt.tokenIds, tt.approve);
    }

    function _testWithoutSetup(TestCase memory tt, bytes memory err)
        internal
        assertExplicitApprovalUnchanged(tt.operator, difference(tt.ownedTokens, tt.tokenIds))
        assertExplicitApproval(tt.operator, tt.tokenIds, tt.approve, err)
    {
        _setExplicitApproval(tt, err);
    }

    function _test(TestCase memory tt, bytes memory err) internal {
        _mint(tt.owner, tt.ownedTokens);
        _testWithoutSetup(tt, err);
    }

    struct Fuzz {
        address owner;
        uint8 numTokensOwned;
        uint8 numTokensToApprove;
        address operator;
        bool approve;
    }

    function _happyCase(Fuzz memory fuzz) internal pure returns (TestCase memory) {
        vm.assume(fuzz.owner != fuzz.operator);
        vm.assume(fuzz.numTokensOwned < 10);
        vm.assume(fuzz.numTokensToApprove <= fuzz.numTokensOwned);

        uint256[] memory ownedTokens = new uint256[](fuzz.numTokensOwned);
        for (uint256 i = 0; i < fuzz.numTokensOwned; i++) {
            ownedTokens[i] = uint256(keccak256(abi.encode(fuzz, i)));
        }

        uint256[] memory tokenIds = new uint256[](fuzz.numTokensToApprove);
        for (uint256 i = 0; i < fuzz.numTokensToApprove; i++) {
            tokenIds[i] = ownedTokens[i];
        }

        TestCase memory tt = TestCase({
            owner: fuzz.owner,
            ownedTokens: ownedTokens,
            caller: fuzz.owner,
            operator: fuzz.operator,
            tokenIds: tokenIds,
            approve: fuzz.approve
        });
        return tt;
    }

    function testHappy(Fuzz memory fuzz) public {
        _test(_happyCase(fuzz), "");
    }

    function testCannotApproveIfNotOwnerOrApproved(Fuzz memory fuzz, address caller) public {
        vm.assume(caller != fuzz.owner);
        vm.assume(caller != fuzz.operator);
        TestCase memory tt = _happyCase(fuzz);
        tt.caller = caller;

        vm.assume(tt.tokenIds.length > 0);
        _test(tt, _unauthorisedERC6464OperatorError(tt.caller, tt.tokenIds[0]));
    }

    function testApprovedCanApprove(Fuzz memory fuzz, address caller) public {
        TestCase memory tt = _happyCase(fuzz);
        vm.assume(caller != tt.owner);
        tt.caller = caller;

        vm.prank(tt.owner);
        erc6464.setApprovalForAll(tt.caller, true);

        _test(tt, "");
    }

    function testExlicitlyApprovedCanApprove(Fuzz memory fuzz) public {
        TestCase memory tt = _happyCase(fuzz);
        tt.approve = true;
        _test(tt, "");
        tt.caller = tt.operator;
        _testWithoutSetup(tt, "");
    }

    function testSequential(Fuzz memory fuzz) public {
        TestCase memory tt = _happyCase(fuzz);
        tt.approve = true;
        _test(tt, "");
        tt.tokenIds = difference(tt.ownedTokens, tt.tokenIds);
        _testWithoutSetup(tt, "");
    }
}

abstract contract SetSingleExplicitApprovalTest is SetExplicitApprovalTest {
    function _setExplicitApproval(TestCase memory tt, bytes memory err) internal virtual override {
        bool fail = err.length > 0;
        for (uint256 i = 0; i < tt.tokenIds.length; i++) {
            if (fail) {
                vm.expectRevert(err);
            } else {
                vm.expectEmit(true, true, true, true, address(erc6464));
                emit IERC6464Events.ExplicitApprovalFor(tt.operator, tt.tokenIds[i], tt.approve);
            }
            vm.prank(tt.caller);
            erc6464.setExplicitApproval(tt.operator, tt.tokenIds[i], tt.approve);

            if (fail) {
                // Not continuing if we expect a revert because the error messages from the multi test cannot be reused and we have already proven that we fail as expected.
                break;
            }
        }
    }
}

abstract contract RevokeAllExplicitApprovalsTest is ERC6464Test {
    struct TestCase {
        address owner;
        uint256[] approvedTokens;
        address[] approvedOperators;
        address caller;
        bool wantRevoked;
    }

    function _testWithoutSetup(TestCase memory tt)
        internal
        assertExplicitApprovals(
            ApprovalsAssertion({
                operators: tt.approvedOperators,
                tokenIds: tt.approvedTokens,
                approved: !tt.wantRevoked,
                fails: false
            })
        )
    {
        vm.expectEmit(true, true, true, true, address(erc6464));
        emit IERC6464Events.AllExplicitApprovalsRevoked(tt.caller);
        vm.prank(tt.caller);
        erc6464.revokeAllExplicitApprovals();
    }

    function _setup(TestCase memory tt) internal {
        _mint(tt.owner, tt.approvedTokens);

        for (uint256 i = 0; i < tt.approvedOperators.length; i++) {
            vm.prank(tt.owner);
            erc6464.setExplicitApproval(tt.approvedOperators[i], tt.approvedTokens, true);
        }
    }

    function _test(TestCase memory tt) internal {
        _setup(tt);
        _testWithoutSetup(tt);
    }

    struct Fuzz {
        address owner;
        uint256[10] tokenIds;
        address[5] approvedOperators;
    }

    function _happyCase(Fuzz memory fuzz) internal pure returns (TestCase memory) {
        for (uint256 i = 0; i < fuzz.approvedOperators.length; i++) {
            vm.assume(fuzz.owner != fuzz.approvedOperators[i]);
        }

        return TestCase({
            owner: fuzz.owner,
            approvedTokens: toUint256s(fuzz.tokenIds),
            approvedOperators: toAddresses(fuzz.approvedOperators),
            caller: fuzz.owner,
            wantRevoked: true
        });
    }

    function testHappy(Fuzz memory fuzz) public {
        _test(_happyCase(fuzz));
    }

    function testUnapprovedCaller(Fuzz memory fuzz, address caller) public {
        vm.assume(caller != fuzz.owner);
        for (uint256 i; i < fuzz.approvedOperators.length; i++) {
            vm.assume(caller != fuzz.approvedOperators[i]);
        }
        // Excluding zero address because it is ERC721 approved by default.
        vm.assume(caller != address(0));

        _test(
            TestCase({
                owner: fuzz.owner,
                approvedTokens: toUint256s(fuzz.tokenIds),
                approvedOperators: toAddresses(fuzz.approvedOperators),
                caller: caller,
                wantRevoked: false
            })
        );
    }
}

abstract contract RevokeAllExplicitApprovalsForTokenTest is ERC6464Test {
    struct TestCase {
        address owner;
        uint256[] approvedTokens;
        uint256[] revokedTokens;
        address[] approvedOperators;
        address caller;
    }

    function _testWithoutSetup(TestCase memory tt, bool expectFail)
        internal
        assertExplicitApprovals(
            ApprovalsAssertion({
                operators: tt.approvedOperators,
                tokenIds: difference(tt.approvedTokens, tt.revokedTokens),
                approved: true,
                fails: expectFail
            })
        )
        assertExplicitApprovals(
            ApprovalsAssertion({
                operators: tt.approvedOperators,
                tokenIds: tt.revokedTokens,
                approved: false,
                fails: expectFail
            })
        )
    {
        for (uint256 i; i < tt.revokedTokens.length; ++i) {
            if (expectFail) {
                vm.expectRevert(_unauthorisedERC6464OperatorError(tt.caller, tt.revokedTokens[i]));
            } else {
                vm.expectEmit(true, true, true, true, address(erc6464));
                emit IERC6464Events.AllExplicitApprovalsRevoked(tt.caller, tt.revokedTokens[i]);
            }

            vm.prank(tt.caller);
            erc6464.revokeAllExplicitApprovals(tt.revokedTokens[i]);
        }
    }

    function _setup(TestCase memory tt) internal {
        _mint(tt.owner, tt.approvedTokens);

        for (uint256 i = 0; i < tt.approvedOperators.length; i++) {
            vm.prank(tt.owner);
            erc6464.setExplicitApproval(tt.approvedOperators[i], tt.approvedTokens, true);
        }
    }

    function _test(TestCase memory tt, bool expectFail) internal {
        _setup(tt);
        _testWithoutSetup(tt, expectFail);
    }

    struct Fuzz {
        address owner;
        uint256[10] tokenIds;
        uint256 numRevoked;
        address[5] approvedOperators;
    }

    function _happyCase(Fuzz memory fuzz) internal view returns (TestCase memory) {
        for (uint256 i = 0; i < fuzz.approvedOperators.length; i++) {
            vm.assume(fuzz.owner != fuzz.approvedOperators[i]);
        }

        fuzz.numRevoked = bound(fuzz.numRevoked, 0, fuzz.tokenIds.length);
        uint256[] memory revokedTokens = new uint[](fuzz.numRevoked);
        for (uint256 i = 0; i < fuzz.numRevoked; i++) {
            revokedTokens[i] = fuzz.tokenIds[i];
        }

        return TestCase({
            owner: fuzz.owner,
            approvedTokens: toUint256s(fuzz.tokenIds),
            revokedTokens: revokedTokens,
            approvedOperators: toAddresses(fuzz.approvedOperators),
            caller: fuzz.owner
        });
    }

    function testHappy(Fuzz memory fuzz) public {
        _test(_happyCase(fuzz), false);
    }

    function testUnapprovedCaller(Fuzz memory fuzz, address caller) public {
        vm.assume(caller != fuzz.owner);
        for (uint256 i; i < fuzz.approvedOperators.length; ++i) {
            vm.assume(caller != fuzz.approvedOperators[i]);
        }
        vm.assume(caller != address(0));

        TestCase memory tt = _happyCase(fuzz);
        tt.caller = caller;
        _test(tt, true);
    }
}

abstract contract ERC721FeaturesTest is ERC6464Test {
    struct TestCase {
        address owner;
        uint256 tokenId;
        address operator;
        bool approved;
    }

    function _setup(TestCase memory tt) internal {
        vm.assume(tt.owner != tt.operator);
        vm.assume(tt.operator != address(0));
        _mint(tt.owner, tt.tokenId);
        vm.prank(tt.owner);
        erc6464.setExplicitApproval(tt.operator, tt.tokenId, tt.approved);
    }

    function testTransferFrom(TestCase memory tt, address receiver) public {
        _setup(tt);
        _assumeERC721Receiver(receiver);
        vm.assume(tt.owner != receiver);

        if (!tt.approved) {
            vm.expectRevert(_unauthorisedERC721TransferError(tt.operator, tt.owner, receiver, tt.tokenId));
        } else {
            vm.expectEmit(true, true, true, true, address(erc6464));
            emit AllExplicitApprovalsRevoked(tt.owner, tt.tokenId);
        }

        vm.prank(tt.operator);
        erc6464.transferFrom(tt.owner, receiver, tt.tokenId);
    }

    function testSafeTransferFrom(TestCase memory tt, address receiver) public {
        _setup(tt);
        _assumeERC721Receiver(receiver);
        vm.assume(tt.owner != receiver);

        if (!tt.approved) {
            vm.expectRevert(_unauthorisedERC721TransferError(tt.operator, tt.owner, receiver, tt.tokenId));
        } else {
            vm.expectEmit(true, true, true, true, address(erc6464));
            emit AllExplicitApprovalsRevoked(tt.owner, tt.tokenId);
        }

        vm.prank(tt.operator);
        erc6464.safeTransferFrom(tt.owner, receiver, tt.tokenId);
    }

    function testApprove(TestCase memory tt, address newOperator) public {
        _setup(tt);
        vm.assume(newOperator != tt.owner);

        if (!tt.approved) {
            vm.expectRevert(_unauthorisedERC721ApproveError(tt.operator, newOperator, tt.tokenId));
        }

        vm.prank(tt.operator);
        erc6464.approve(newOperator, tt.tokenId);

        assertEq(erc6464.getApproved(tt.tokenId), tt.approved ? newOperator : address(0));
    }
}
