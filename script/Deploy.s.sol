// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

import {SpendRouter} from "../src/SpendRouter.sol";
import {SpendPermissionManager} from "spend-permissions/SpendPermissionManager.sol";

/**
 * @notice Deploy the SpendRouter contract.
 *
 * @dev Before deploying contracts, make sure dependencies have been installed at the latest or otherwise specific
 * versions using `forge install [OPTIONS] [DEPENDENCIES]`.
 *
 * forge script Deploy --account dev --sender $SENDER --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url
 * $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
 */
contract Deploy is Script {
    address constant SPEND_PERMISSION_MANAGER = 0xf85210B21cC50302F477BA56686d2019dC9b67Ad;

    function run() public {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }
    function deploy() internal {
        SpendRouter router = new SpendRouter{salt: 0}(SpendPermissionManager(payable(SPEND_PERMISSION_MANAGER)));
        logAddress("SpendRouter", address(router));
    }
    
    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
