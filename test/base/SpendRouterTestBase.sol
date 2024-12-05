// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PublicERC6492Validator} from "spend-permissions/PublicERC6492Validator.sol";
import {SpendPermissionManager} from "spend-permissions/SpendPermissionManager.sol";
import {SpendRouter} from "src/SpendRouter.sol";
import {MockCoinbaseSmartWallet} from "../mocks/MockCoinbaseSmartWallet.sol";

import {Test, console2} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {MockERC20} from "solady/../test/utils/mocks/MockERC20.sol";

contract SpendRouterTestBase is Test {
    // Core contracts
    SpendPermissionManager public permissionManager;
    SpendRouter public router;
    PublicERC6492Validator public validator;

    // Test tokens
    MockERC20 public token;

    // Test accounts
    uint256 internal ownerPk;
    address internal owner;
    uint256 internal appPk;
    address internal app;
    uint256 internal recipientPk;
    address internal recipient;
    CoinbaseSmartWallet internal account;

    // Constants
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public virtual {
        // Generate test accounts
        ownerPk = uint256(keccak256("owner"));
        owner = vm.addr(ownerPk);
        appPk = uint256(keccak256("app"));
        app = vm.addr(appPk);
        recipientPk = uint256(keccak256("recipient"));
        recipient = vm.addr(recipientPk);

        // Deploy test token
        token = new MockERC20("Test Token", "TEST", 18);

        // Deploy core contracts
        validator = new PublicERC6492Validator();
        permissionManager = new SpendPermissionManager(validator, address(0)); // TODO: Add MagicSpend paths to router
            // contract and tests
        router = new SpendRouter(permissionManager);

        // Deploy and initialize account
        account = new MockCoinbaseSmartWallet();
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(owner);
        account.initialize(owners);

        // Add permission manager as owner of account
        vm.prank(owner);
        account.addOwnerAddress(address(permissionManager));
    }

    function _createPermission(
        address tokenAddress,
        uint160 allowance,
        uint48 period,
        uint48 start,
        uint48 end,
        uint256 salt
    ) internal view returns (SpendPermissionManager.SpendPermission memory) {
        return router.constructPermission(
            address(account), app, recipient, tokenAddress, allowance, period, start, end, salt
        );
    }

    function _signPermission(SpendPermissionManager.SpendPermission memory permission)
        internal
        view
        returns (bytes memory)
    {
        bytes32 permissionHash = permissionManager.getHash(permission);
        bytes32 replaySafeHash = CoinbaseSmartWallet(payable(permission.account)).replaySafeHash(permissionHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, replaySafeHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        return _applySignatureWrapper(0, signature);
    }

    function _applySignatureWrapper(uint256 ownerIndex, bytes memory signatureData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(CoinbaseSmartWallet.SignatureWrapper(ownerIndex, signatureData));
    }

    function _approvePermission(SpendPermissionManager.SpendPermission memory permission) internal {
        bytes memory signature = _signPermission(permission);
        permissionManager.approveWithSignature(permission, signature);
    }
}
