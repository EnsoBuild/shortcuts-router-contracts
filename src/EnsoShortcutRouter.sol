// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { VM } from "enso-weiroll/VM.sol";
import { MinimalWallet } from "shortcuts-contracts/wallet/MinimalWallet.sol";
import { AccessController } from "shortcuts-contracts/access/AccessController.sol";

contract EnsoShortcuts is VM, MinimalWallet, AccessController {
    address public executor;

    constructor(address owner_, address executor_) {
        _setPermission(OWNER_ROLE, owner_, true);
        executor = executor_;
    }

    // @notice Execute a shortcut
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function executeShortcut(
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory) {
        // we could use the AccessController here to check if the msg.sender is the executor address
        // but as it's a hot path we do a less gas intensive check
        if (msg.sender != executor) revert NotPermitted();
        return _execute(commands, state);
    }
}

contract EnsoShortcutRouter {
    address private constant _ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    EnsoShortcuts public immutable enso;

    error WrongValue();
    error AmountTooLow();
    error ArrayMismatch();

    constructor(address owner_) {
        enso = new EnsoShortcuts(owner_, address(this));
    }

    // @notice Route a single token via an Enso Shortcut
    // @param tokenIn The address of the token to send
    // @param amountIn The amount of the token to send
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function routeSingle(
        address tokenIn,
        uint256 amountIn,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) public payable returns (bytes[] memory returnData) {
        if (tokenIn == _ETH) {
            if (msg.value != amountIn) revert WrongValue();
        } else {
            if (msg.value != 0) revert WrongValue();
            IERC20(tokenIn).transferFrom(msg.sender, address(enso), amountIn);
        }
        returnData = enso.executeShortcut{value: msg.value}(commands, state);
    }

    // @notice Route multiple tokens via an Enso Shortcut
    // @param tokensIn The addresses of the tokens to send
    // @param amountsIn The amounts of the tokens to send
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function routeMulti(
        address[] memory tokensIn,
        uint256[] memory amountsIn,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) public payable returns (bytes[] memory returnData) {
        uint256 length = tokensIn.length;
        if (amountsIn.length != length) revert ArrayMismatch();

        bool ethFlag;
        address tokenIn;
        uint256 amountIn;
        for (uint256 i; i < length; ++i) {
            tokenIn = tokensIn[i];
            amountIn = amountsIn[i];
            if (tokenIn == _ETH) {
                ethFlag = true;
                if (msg.value != amountIn) revert WrongValue();
            } else {
                IERC20(tokenIn).transferFrom(msg.sender, address(enso), amountIn);
            }
        }
        if (!ethFlag && msg.value != 0) revert WrongValue();
        
        returnData = enso.executeShortcut{value: msg.value}(commands, state);
    }

    // @notice Route a single token via an Enso Shortcut and revert if there is insufficient token received
    // @param tokenIn The address of the token to send
    // @param tokenOut The address of the token to receive
    // @param amountIn The amount of the token to send
    // @param minAmountOut The minimum amount of the token to receive
    // @param receiver The address of the wallet that will receive the tokens
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function safeRouteSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory returnData) {
        uint256 balance = tokenOut == _ETH ? receiver.balance : IERC20(tokenOut).balanceOf(receiver);
        returnData = routeSingle(tokenIn, amountIn, commands, state);
        uint256 amountOut;
        if (tokenOut == _ETH) {
            amountOut = receiver.balance - balance;
        } else {
            amountOut = IERC20(tokenOut).balanceOf(receiver) - balance;
        }
        if (amountOut < minAmountOut) revert AmountTooLow();
    }

    // @notice Route multiple tokens via an Enso Shortcut and revert if there is insufficient tokens received
    // @param tokensIn The addresses of the tokens to send
    // @param tokensOut The addresses of the tokens to receive
    // @param amountsIn The amounts of the tokens to send
    // @param minAmountsOut The minimum amounts of the tokens to receive
    // @param receiver The address of the wallet that will receive the tokens
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function safeRouteMulti(
        address[] memory tokensIn,
        address[] memory tokensOut,
        uint256[] memory amountsIn,
        uint256[] memory minAmountsOut,
        address receiver,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory returnData) {
        uint256 length = tokensOut.length;
        if (minAmountsOut.length != length) revert ArrayMismatch();

        uint256[] memory balances = new uint256[](length);

        address tokenOut;
        for (uint256 i; i < length; ++i) {
            tokenOut = tokensOut[i];
            balances[i] = tokenOut == _ETH ? receiver.balance : IERC20(tokenOut).balanceOf(receiver);
        }

        returnData = routeMulti(tokensIn, amountsIn, commands, state);

        uint256 amountOut;
        for (uint256 i; i < length; ++i) {
            tokenOut = tokensOut[i];
            if (tokenOut == _ETH) {
                amountOut = receiver.balance - balances[i];
            } else {
                amountOut = IERC20(tokenOut).balanceOf(receiver) - balances[i];
            }
            if (amountOut < minAmountsOut[i]) revert AmountTooLow();
        }
    }
}
