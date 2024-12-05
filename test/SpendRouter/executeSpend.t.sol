// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SpendPermissionManager} from "spend-permissions/SpendPermissionManager.sol";
import {SpendRouter} from "src/SpendRouter.sol";
import {SpendRouterTestBase} from "../base/SpendRouterTestBase.sol";

contract ExecuteSpendTest is SpendRouterTestBase {
    function test_executeSpend_nativeToken() public {
        // Create and approve permission
        uint160 allowance = 1 ether;
        uint48 period = 1 days;
        uint48 start = uint48(block.timestamp);
        uint48 end = start + period;
        SpendPermissionManager.SpendPermission memory permission =
            _createPermission(NATIVE_TOKEN, allowance, period, start, end, 0);
        _approvePermission(permission);

        // Fund account
        vm.deal(address(account), allowance);

        // Execute spend
        uint160 spendAmount = 0.5 ether;
        vm.prank(app);
        bool success = router.executeSpend(permission, spendAmount);

        // Verify results
        assertTrue(success);
        assertEq(address(recipient).balance, spendAmount);
        assertEq(address(account).balance, allowance - spendAmount);
    }

    function test_executeSpend_erc20() public {
        // Create and approve permission
        uint160 allowance = 1000e18;
        uint48 period = 1 days;
        uint48 start = uint48(block.timestamp);
        uint48 end = start + period;
        SpendPermissionManager.SpendPermission memory permission =
            _createPermission(address(token), allowance, period, start, end, 0);
        _approvePermission(permission);

        // Fund account
        token.mint(address(account), allowance);

        // Execute spend
        uint160 spendAmount = 500e18;
        vm.prank(app);
        bool success = router.executeSpend(permission, spendAmount);

        // Verify results
        assertTrue(success);
        assertEq(token.balanceOf(recipient), spendAmount);
        assertEq(token.balanceOf(address(account)), allowance - spendAmount);
    }

    function test_executeSpend_revert_invalidSpender() public {
        SpendPermissionManager.SpendPermission memory permission = _createPermission(
            NATIVE_TOKEN, 1 ether, 1 days, uint48(block.timestamp), uint48(block.timestamp + 1 days), 0
        );
        permission.spender = address(0x123); // Set wrong spender

        vm.prank(app);
        vm.expectRevert(SpendRouter.InvalidSpender.selector);
        router.executeSpend(permission, 0.5 ether);
    }

    function test_executeSpend_revert_zeroAmount() public {
        SpendPermissionManager.SpendPermission memory permission = _createPermission(
            NATIVE_TOKEN, 1 ether, 1 days, uint48(block.timestamp), uint48(block.timestamp + 1 days), 0
        );
        _approvePermission(permission);

        vm.prank(app);
        vm.expectRevert(SpendRouter.ZeroAmount.selector);
        router.executeSpend(permission, 0);
    }

    function test_executeSpend_revert_unauthorizedSender() public {
        SpendPermissionManager.SpendPermission memory permission = _createPermission(
            NATIVE_TOKEN, 1 ether, 1 days, uint48(block.timestamp), uint48(block.timestamp + 1 days), 0
        );
        _approvePermission(permission);

        address unauthorizedSender = makeAddr("unauthorized");
        vm.prank(unauthorizedSender);
        vm.expectRevert(abi.encodeWithSelector(SpendRouter.UnauthorizedSender.selector, unauthorizedSender, app));
        router.executeSpend(permission, 0.5 ether);
    }
}
