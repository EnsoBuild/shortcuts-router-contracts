// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/EnsoShortcutRouter.sol";

struct DeployerResult {
    EnsoShortcutRouter router;
    EnsoShortcuts shortcuts;
}

contract Deployer is Script {
    function run() public returns (DeployerResult memory result) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address owner = 0xca702d224D61ae6980c8c7d4D98042E22b40FFdB;

        result.router = new EnsoShortcutRouter{salt: "EnsoShortcutRouter"}(owner);
        result.shortcuts = result.router.enso();

        vm.stopBroadcast();
    }
}
