// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";

import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {AragonTest} from "./base/AragonTest.sol";
import {VaultPluginSetup} from "../src/VaultPluginSetup.sol";
import {VaultPlugin} from "../src/VaultPlugin.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

abstract contract VaultPluginTest is AragonTest {
    DAO internal dao;
    VaultPlugin internal plugin;
    VaultPluginSetup internal setup;
    MockToken internal DAI;

    function setUp() public virtual {
        setup = new VaultPluginSetup();
        DAI = new MockToken("DAI Coin", "DAI");
        bytes memory setupData = abi.encode(DAI);

        (DAO _dao, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        dao = _dao;
        plugin = VaultPlugin(_plugin);
    }
}

contract VaultPluginInitializeTest is VaultPluginTest {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize() public {
        assertEq(address(plugin.dao()), address(dao));
        assertEq(plugin.asset(), address(DAI));
    }

    function test_reverts_if_reinitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(dao, IERC20MetadataUpgradeable(address(DAI)));
    }
}

contract VaultPluginPauseTest is VaultPluginTest {
    function setUp() public override {
        super.setUp();
    }

    function test_pause() public {
        vm.prank(address(dao));

        plugin.togglePause();
        assertEq(plugin.isPaused(), true);
    }

    function test_reverts_if_not_auth() public {
        // error DaoUnauthorized({dao: address(_dao),  where: _where,  who: _who,permissionId: _permissionId });
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                dao,
                plugin,
                address(this),
                keccak256("PAUSE_PERMISSION")
            )
        );
        plugin.togglePause();
    }
}
