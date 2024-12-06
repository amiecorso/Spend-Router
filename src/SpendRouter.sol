// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SpendPermissionManager} from "spend-permissions/SpendPermissionManager.sol";

/// @title SpendRouter
/// @notice A singleton router contract that spends and routes funds to designated recipients.
contract SpendRouter {
    using SafeERC20 for IERC20;

    SpendPermissionManager public immutable PERMISSION_MANAGER;

    /// @notice ERC-7528 native token address used by SpendPermissionManager
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error UnauthorizedSender(address caller, address expected);
    error MalformedExtraData(uint256 length, bytes extraData);
    error ZeroAddress();

    constructor(SpendPermissionManager spendPermissionManager) {
        PERMISSION_MANAGER = spendPermissionManager;
    }

    /// @notice Accept receiving native token
    receive() external payable {}

    /// @notice Executes a spend using an existing permission
    function executeSpend(SpendPermissionManager.SpendPermission calldata permission, uint160 amount) external {
        // decode and verify addresses
        (address app, address recipient) = decodeExtraData(permission.extraData);
        if (msg.sender != app) revert UnauthorizedSender(msg.sender, app);
        if (recipient == address(0)) revert ZeroAddress();

        // spend to pull tokens into this contract
        PERMISSION_MANAGER.spend(permission, amount);

        // forward the received tokens to the recipient
        if (permission.token == NATIVE_TOKEN_ADDRESS) {
            SafeTransferLib.safeTransferETH(payable(recipient), amount);
        } else {
            IERC20(permission.token).safeTransfer(recipient, amount);
        }
    }

    /// @notice Helper function to construct a properly formatted `SpendPermission.extraData`
    function encodeExtraData(address app, address recipient) public pure returns (bytes memory extraData) {
        if (app == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();

        return abi.encode(app, recipient);
    }

    /// @dev Internal helper to decode app and recipient addresses from permission extraData
    function decodeExtraData(bytes memory extraData) public pure returns (address app, address recipient) {
        if (extraData.length != 64) revert MalformedExtraData(extraData.length, extraData);
        (app, recipient) = abi.decode(extraData, (address, address));
    }
}
