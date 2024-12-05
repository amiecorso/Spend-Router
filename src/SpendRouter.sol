// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// External imports sorted alphabetically

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Internal imports
import {SpendPermissionManager} from "spend-permissions/SpendPermissionManager.sol";

/// @title SpendRouter
/// @notice A singleton router contract that executes spends for Spend Permissions and routes funds to designated
/// recipients
/// @dev This contract verifies app permissions and routes funds during spend execution
contract SpendRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Reference to the SpendPermissionManager contract
    SpendPermissionManager public immutable PERMISSION_MANAGER;

    /// @notice Native token address constant from SpendPermissionManager
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Expected amount to receive during spend execution
    uint256 private _expectedAmount;

    /// @dev Struct to decode addresses from extraData
    struct EncodedAddresses {
        address app;
        address recipient;
    }

    /* ========== Events ========== */

    /// @notice Emitted when funds are successfully routed from an account to a recipient
    /// @param recipient Address receiving the funds
    /// @param app Address of the app that initiated the spend
    /// @param account Address of the account whose funds were spent
    /// @param token Address of the token that was transferred (NATIVE_TOKEN_ADDRESS for ETH)
    /// @param amount Number of tokens/ETH transferred
    event SpendRouted(
        address indexed recipient, address indexed app, address indexed account, address token, uint256 amount
    );

    /* ========== Custom Errors ========== */

    /// @dev Thrown when receiving ETH outside of spend execution
    error UnauthorizedReceive(address sender, uint256 value);
    /// @dev Thrown when received amount doesn't match expected amount
    error UnexpectedAmount(uint256 received, uint256 expected);
    error UnauthorizedSender(address caller, address encoded);
    error MalformedExtraData(uint256 length, bytes extraData);
    error ZeroAmount();
    error InvalidPermission();
    error InvalidSpender();
    error ZeroAppAddress();
    error ZeroRecipientAddress();
    error InsufficientBalance(uint256 balance, uint256 required);
    error InvalidTokenTransfer(address token, address from, address to, uint256 amount);

    constructor(SpendPermissionManager spendPermissionManager) {
        PERMISSION_MANAGER = spendPermissionManager;
    }

    /// @notice Executes a spend using an existing permission
    /// @param permission The spend permission to use
    /// @param amount The amount to spend
    /// @return success True if both the spend and token transfer succeeded, false otherwise
    function executeSpend(SpendPermissionManager.SpendPermission calldata permission, uint160 amount)
        external
        nonReentrant
        returns (bool success)
    {
        // Checks
        if (amount == 0) revert ZeroAmount();
        if (permission.spender != address(this)) revert InvalidSpender();

        // Decode and verify addresses
        EncodedAddresses memory encoded = _decodeAddresses(permission.extraData);
        if (encoded.app != msg.sender) revert UnauthorizedSender(msg.sender, encoded.app);
        if (encoded.recipient == address(0)) revert ZeroRecipientAddress();

        // Effects
        _expectedAmount = amount;

        // Interactions
        try PERMISSION_MANAGER.spend(permission, amount) {
            // Forward the received tokens to the recipient
            if (permission.token == NATIVE_TOKEN_ADDRESS) {
                SafeTransferLib.safeTransferETH(payable(encoded.recipient), amount);
            } else {
                IERC20(permission.token).safeTransfer(encoded.recipient, amount);
            }

            emit SpendRouted(encoded.recipient, msg.sender, permission.account, permission.token, amount);
            success = true;
        } catch {
            success = false;
        }

        // Clean up
        _expectedAmount = 0;

        return success;
    }

    /// @notice Protects against unwanted receives outside of spend execution
    receive() external payable {
        if (_expectedAmount == 0) revert UnauthorizedReceive(msg.sender, msg.value);
        if (msg.value != _expectedAmount) revert UnexpectedAmount(msg.value, _expectedAmount);
    }

    /// @notice Helper function to construct a properly formatted SpendPermission struct
    /// @param account The account granting the permission
    /// @param app The app address to encode in extraData
    /// @param recipient The recipient address to encode in extraData
    /// @param token The token address (use NATIVE_TOKEN for ETH)
    /// @param allowance Maximum amount spendable per period
    /// @param period Time duration for allowance reset
    /// @param start Start time of the permission
    /// @param end End time of the permission
    /// @param salt Arbitrary salt to differentiate permissions
    /// @return permission The formatted SpendPermission struct
    function constructPermission(
        address account,
        address app,
        address recipient,
        address token,
        uint160 allowance,
        uint48 period,
        uint48 start,
        uint48 end,
        uint256 salt
    ) external view returns (SpendPermissionManager.SpendPermission memory permission) {
        if (app == address(0)) revert ZeroAppAddress();
        if (recipient == address(0)) revert ZeroRecipientAddress();

        return SpendPermissionManager.SpendPermission({
            account: account,
            spender: address(this),
            token: token,
            allowance: allowance,
            period: period,
            start: start,
            end: end,
            salt: salt,
            extraData: abi.encode(app, recipient)
        });
    }

    /// @dev Internal helper to decode app and recipient addresses from permission extraData
    /// @param extraData The encoded addresses (must be exactly 64 bytes)
    /// @return encoded Struct containing decoded app and recipient addresses
    function _decodeAddresses(bytes memory extraData) internal pure returns (EncodedAddresses memory encoded) {
        if (extraData.length != 64) revert MalformedExtraData(extraData.length, extraData);

        (address app, address recipient) = abi.decode(extraData, (address, address));
        return EncodedAddresses({app: app, recipient: recipient});
    }
}
