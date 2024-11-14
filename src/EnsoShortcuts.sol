// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.24;

import { VM } from "enso-weiroll/VM.sol";

interface IEnsoShortcuts {
    function executeShortcut(
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory);
}

contract EnsoShortcuts is IEnsoShortcuts, VM {
    address public executor;

    error NotPermitted();

    constructor(address executor_) {
        executor = executor_;
    }

    // @notice Execute a shortcut
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function executeShortcut(
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory) {
        if (msg.sender != executor) revert NotPermitted();
        return _execute(commands, state);
    }
}
