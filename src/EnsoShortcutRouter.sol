// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { EnsoWalletFactory, EnsoWallet } from "shortcuts-contracts/EnsoWalletFactory.sol";

contract EnsoShortcutRouter {
    EnsoWalletFactory public constant factory = EnsoFactory(0x7fEA6786D291A87fC4C98aFCCc5A5d3cFC36bc7b);
    IEnsoWallet public immutable wallet;
    constructor() {
        wallet = factory.deploy(bytes32(0), [], []);
    }


}
