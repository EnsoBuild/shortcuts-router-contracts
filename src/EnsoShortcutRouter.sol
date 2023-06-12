// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

interface IEnsoWalletFactory {
    function deploy(bytes32, bytes32[] calldata, bytes[] calldata) external returns (IEnsoWallet);
}

interface IEnsoWallet {
    function executeShortcut(bytes32, bytes32[] calldata, bytes[] calldata) external payable returns (bytes[] memory);
}

contract EnsoShortcutRouter {
    address private constant _ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IEnsoWalletFactory private constant _FACTORY = IEnsoWalletFactory(0x7fEA6786D291A87fC4C98aFCCc5A5d3cFC36bc7b);

    IEnsoWallet public immutable wallet;

    error WrongValue();
    error AmountTooLow();

    constructor() {
        wallet = _FACTORY.deploy(bytes32(0), new bytes32[](0), new bytes[](0));
    }

    function route(
        address tokenIn,
        uint256 amountIn,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) public payable returns (bytes[] memory returnData) {
        if (tokenIn == _ETH) {
            if (msg.value != amountIn) revert WrongValue();
        } else {
            if (msg.value != 0) revert WrongValue();
            IERC20(tokenIn).transferFrom(msg.sender, address(wallet), amountIn);
        }
        returnData = wallet.executeShortcut{value: msg.value}(bytes32(0), commands, state);
    }

    function safeRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32[] calldata commands,
        bytes[] calldata state
    ) external payable returns (bytes[] memory returnData) {
        uint256 balance = tokenOut == _ETH ? msg.sender.balance : IERC20(tokenOut).balanceOf(msg.sender);
        returnData = route(tokenIn, amountIn, commands, state);
        uint256 amountOut;
        if (tokenOut == _ETH) {
            amountOut = msg.sender.balance - balance;
        } else {
            amountOut = IERC20(tokenOut).balanceOf(msg.sender) - balance;
        }
        if (amountOut < minAmountOut) revert AmountTooLow();
    }
}
