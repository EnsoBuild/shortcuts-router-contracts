// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { EnsoShortcuts } from "./EnsoShortcuts.sol";
import { SafeERC20, IERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

struct Token {
    IERC20 token;
    uint256 amount;
}

contract EnsoShortcutRouter {
    using SafeERC20 for IERC20;

    IERC20 private constant _ETH = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    EnsoShortcuts public immutable enso;

    error WrongValue(uint256 value, uint256 amount);
    error AmountTooLow(address token);
    error Duplicate(address token);

    constructor(address owner_) {
        enso = new EnsoShortcuts(owner_, address(this));
    }

    // @notice Route a single token via an Enso Shortcut
    // @param tokenIn The address of the token to send
    // @param amountIn The amount of the token to send
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function routeSingle(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) public payable returns (bytes[] memory returnData) {
        if (tokenIn == _ETH) {
            if (msg.value != amountIn) revert WrongValue(msg.value, amountIn);
        } else {
            if (msg.value != 0) revert WrongValue(msg.value, 0);
            tokenIn.safeTransferFrom(msg.sender, address(enso), amountIn);
        }
        returnData = enso.executeShortcut{value: msg.value}(commands, state);
    }

    // @notice Route multiple tokens via an Enso Shortcut
    // @param tokensIn The addresses and amounts of the tokens to send
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function routeMulti(
        Token[] calldata tokensIn,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) public payable returns (bytes[] memory returnData) {
        bool ethFlag;
        IERC20 tokenIn;
        uint256 amountIn;
        for (uint256 i; i < tokensIn.length; ++i) {
            tokenIn = tokensIn[i].token;
            amountIn = tokensIn[i].amount;
            if (tokenIn == _ETH) {
                if (ethFlag) revert Duplicate(address(_ETH));
                ethFlag = true;
                if (msg.value != amountIn) revert WrongValue(msg.value, amountIn);
            } else {
                tokenIn.safeTransferFrom(msg.sender, address(enso), amountIn);
            }
        }
        if (!ethFlag && msg.value != 0) revert WrongValue(msg.value, 0);
        
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
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory returnData) {
        uint256 balance = tokenOut == _ETH ? receiver.balance : tokenOut.balanceOf(receiver);
        returnData = routeSingle(tokenIn, amountIn, commands, state);
        uint256 amountOut;
        if (tokenOut == _ETH) {
            amountOut = receiver.balance - balance;
        } else {
            amountOut = tokenOut.balanceOf(receiver) - balance;
        }
        if (amountOut < minAmountOut) revert AmountTooLow(address(tokenOut));
    }

    // @notice Route multiple tokens via an Enso Shortcut and revert if there is insufficient tokens received
    // @param tokensIn The addresses and amounts of the tokens to send
    // @param tokensOut The addresses and minimum amounts of the tokens to receive
    // @param receiver The address of the wallet that will receive the tokens
    // @param commands An array of bytes32 values that encode calls
    // @param state An array of bytes that are used to generate call data for each command
    function safeRouteMulti(
        Token[] calldata tokensIn,
        Token[] calldata tokensOut,
        address receiver,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory returnData) {
        uint256 length = tokensOut.length;
        uint256[] memory balances = new uint256[](length);

        IERC20 tokenOut;
        for (uint256 i; i < length; ++i) {
            tokenOut = tokensOut[i].token;
            balances[i] = tokenOut == _ETH ? receiver.balance : tokenOut.balanceOf(receiver);
        }

        returnData = routeMulti(tokensIn, commands, state);

        uint256 amountOut;
        for (uint256 i; i < length; ++i) {
            tokenOut = tokensOut[i].token;
            if (tokenOut == _ETH) {
                amountOut = receiver.balance - balances[i];
            } else {
                amountOut = tokenOut.balanceOf(receiver) - balances[i];
            }
            if (amountOut < tokensOut[i].amount) revert AmountTooLow(address(tokenOut));
        }
    }
}
