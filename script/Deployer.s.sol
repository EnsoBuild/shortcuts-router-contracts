// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/EnsoShortcutRouter.sol";
import "../src/EnsoShortcuts.sol";

struct DeployerResult {
    EnsoShortcutRouter router;
    EnsoShortcuts shortcuts;
}

contract Deployer is Script {
    function run() public returns (DeployerResult memory result) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address initializer = address(0x826e0BB2276271eFdF2a500597f37b94f6c153bA);

        result.router = new EnsoShortcutRouter{salt: "EnsoShortcutRouter"}(initializer);
        result.shortcuts = new EnsoShortcuts{salt: "EnsoShortcuts"}(address(result.router));
        result.router.initialize(address(result.shortcuts));

        vm.stopBroadcast();
    }
}
