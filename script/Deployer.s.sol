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

        address owner = 0xfae0bbFD75307865Dcdf21d9deFEFEDEee718431;

        result.router = new EnsoShortcutRouter{salt: "EnsoShortcutRouter"}(owner);
        result.shortcuts = result.router.enso();

        vm.stopBroadcast();
    }
}
