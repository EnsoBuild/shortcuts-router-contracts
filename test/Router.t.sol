// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/forge-std/src/Test.sol";
import "../src/EnsoShortcutRouter.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVault.sol";
import "./utils/WeirollPlanner.sol";

contract RouterTest is Test {
    EnsoShortcutRouter public router;
    MockERC20 public token;
    MockVault public vault;

    string _rpcURL = vm.envString("ETHEREUM_RPC_URL");
    uint256 _ethereumFork;

    uint256 public constant AMOUNT = 10 ** 18;

    

    function setUp() public {
        _ethereumFork = vm.createFork(_rpcURL);
        vm.selectFork(_ethereumFork);
        router = new EnsoShortcutRouter(address(this));
        token = new MockERC20("Test", "TST");
        vault = new MockVault("Vault", "VLT", address(token));
        token.mint(address(this), AMOUNT * 10);
    }

    function testVaultDeposit() public {
        vm.selectFork(_ethereumFork);

        token.approve(address(router), AMOUNT);

        bytes32[] memory commands = new bytes32[](3);
        bytes[] memory state = new bytes[](3);

        commands[0] = WeirollPlanner.buildCommand(
            token.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs
            0xff, // no output
            address(token)
        );
    
        commands[1] = WeirollPlanner.buildCommand(
            vault.deposit.selector,
            0x01, // call
            0x01ffffffffff, // 1 input
            0xff, // no output
            address(vault)
        );

        commands[2] = WeirollPlanner.buildCommand(
            vault.transfer.selector,
            0x01, // call
            0x0201ffffffff, // 2 inputs
            0xff, // no output
            address(vault)
        );

        state[0] = abi.encode(address(vault));
        state[1] = abi.encode(AMOUNT);
        state[2] = abi.encode(address(this));

        router.safeRouteSingle(address(token), address(vault), AMOUNT, AMOUNT, address(this), commands, state);
        assertEq(AMOUNT, vault.balanceOf(address(this)));
    }

    function testFailVaultDepositNoApproval() public {
        vm.selectFork(_ethereumFork);

        bytes32[] memory commands = new bytes32[](3);
        bytes[] memory state = new bytes[](3);

        commands[0] = WeirollPlanner.buildCommand(
            token.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs
            0xff, // no output
            address(token)
        );
    
        commands[1] = WeirollPlanner.buildCommand(
            vault.deposit.selector,
            0x01, // call
            0x01ffffffffff, // 1 input
            0xff, // no output
            address(vault)
        );

        commands[2] = WeirollPlanner.buildCommand(
            vault.transfer.selector,
            0x01, // call
            0x0201ffffffff, // 2 inputs
            0xff, // no output
            address(vault)
        );

        state[0] = abi.encode(address(vault));
        state[1] = abi.encode(AMOUNT);
        state[2] = abi.encode(address(this));

        router.safeRouteSingle(address(token), address(vault), AMOUNT, AMOUNT, address(this), commands, state);
    }

    function testFailVaultDepositNoTransfer() public {
        vm.selectFork(_ethereumFork);

        token.approve(address(router), AMOUNT);

        // Shortcut does not transfer funds after deposit
        bytes32[] memory commands = new bytes32[](2);
        bytes[] memory state = new bytes[](2);
        
        commands[0] = WeirollPlanner.buildCommand(
            token.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs
            0xff, // no output
            address(token)
        );
    
        commands[1] = WeirollPlanner.buildCommand(
            vault.deposit.selector,
            0x01, // call
            0x01ffffffffff, // 1 input
            0xff, // no output
            address(vault)
        );

        state[0] = abi.encode(address(vault));
        state[1] = abi.encode(AMOUNT);

        router.safeRouteSingle(address(token), address(vault), AMOUNT, AMOUNT, address(this), commands, state);
    }

    function testUnsafeVaultDepositNoTransfer() public {
        vm.selectFork(_ethereumFork);

        token.approve(address(router), AMOUNT);

        // Shortcut does not transfer funds after deposit
        bytes32[] memory commands = new bytes32[](2);
        bytes[] memory state = new bytes[](2);
        
        commands[0] = WeirollPlanner.buildCommand(
            token.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs
            0xff, // no output
            address(token)
        );
    
        commands[1] = WeirollPlanner.buildCommand(
            vault.deposit.selector,
            0x01, // call
            0x01ffffffffff, // 1 input
            0xff, // no output
            address(vault)
        );

        state[0] = abi.encode(address(vault));
        state[1] = abi.encode(AMOUNT);

        router.routeSingle(address(token), AMOUNT, commands, state);
        // Funds left in router's wallet!
        assertEq(AMOUNT, vault.balanceOf(address(router.enso())));
    }
}
