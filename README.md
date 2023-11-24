# BRB Hackathon

> This project uses Foundry. See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

follow along on [Notion](https://aragonorg.notion.site/BRB-Vault-Workshop-e4c2af550a654d5a9a408a5bf2595743)

# Part 1: Plugin

## Install dependencies

```bash
forge install && pnpm install
```

## Create Plugin

create a new file `src/VaultPlugin.sol`

This is the minimial plugin boilerplate, We are inhereting from the ERC4620 and Plugin

```typescript
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {PluginUUPSUpgradeable, IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {ERC4626Upgradeable, IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract VaultPlugin is PluginUUPSUpgradeable, ERC4626Upgradeable {
    function initialize(IDAO _dao, IERC20MetadataUpgradeable _asset) external initializer {
        __PluginUUPSUpgradeable_init(_dao);
        __ERC4626_init(_asset);
    }
}
```

### Override functions

We want to change the default behaviour of the vault such that deposits do to the dao and withdrawals come from the dao. we also need to override total assets to point to the dao also

```typescript

    function totalAssets() public view virtual override returns (uint256) {
        revert("not implemented");
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // silence unused local variable warning
        (caller, receiver, assets, shares);
        revert("not implemented");
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // silence unused local variable warning
        (caller, receiver, owner, assets, shares);
        revert("not implemented");
    }

    function _withdrawFromDao(address to, uint256 assets) internal {}
```

### Pausability

We want the dao to have control over if depositing is allowed

```typescript
    bytes32 public constant PAUSE_PERMISSION_ID = keccak256("PAUSE_PERMISSION");
    bool public isPaused;

    event VaultPaused(bool);
    error ContractPaused();

    function togglePause() external auth(PAUSE_PERMISSION_ID) {
        isPaused = !isPaused;
        emit VaultPaused(isPaused);
    }
```

### `totalAssets()`

```typescript
    function totalAssets() public view virtual override returns (uint256) {
        return IERC20Upgradeable(asset()).balanceOf(address(dao()));
    }
```

### `_deposit()`

```typescript
function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (isPaused) revert ContractPaused();

        SafeERC20Upgradeable.safeTransferFrom({
            token: IERC20Upgradeable(asset()),
            from: caller,
            to: address(dao()),
            value: assets
        });

        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }
```

### `_withdraw()`

```typescript
function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        _withdrawFromDao(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }
```

### `_withdrawFromDao()`

```typescript
function _withdrawFromDao(address to, uint256 assets) internal {
        IDAO.Action[] memory action = new IDAO.Action[](1);
        action[0] = IDAO.Action({
            to: asset(),
            value: 0,
            data: abi.encodeCall(IERC20Upgradeable.transfer, (to, assets))
        });

        // this plugin must have Execute permission on the vault
        dao().execute({
            // The target contract
            _callId: bytes32(abi.encodePacked(to, assets, ++nonce)),
            // The array of actions the DAO will execute
            _actions: action,
            // are any of the transactions allowed to fail? 0 === none
            _allowFailureMap: 0
        });
}
```

## Complete Plugin

create the `/src/VaultPluginSetup.sol`

```typescript
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {PluginUUPSUpgradeable, IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {ERC4626Upgradeable, IERC20MetadataUpgradeable, IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract VaultPlugin is PluginUUPSUpgradeable, ERC4626Upgradeable {
    bytes32 public constant PAUSE_PERMISSION_ID = keccak256("PAUSE_PERMISSION");
    uint256 private nonce = 0;
    bool public isPaused;

    event VaultPaused(bool);
    error ContractPaused();

    function togglePause() external auth(PAUSE_PERMISSION_ID) {
        isPaused = !isPaused;
        emit VaultPaused(isPaused);
    }

    function initialize(IDAO _dao, IERC20MetadataUpgradeable _asset) external initializer {
        __PluginUUPSUpgradeable_init(_dao);
        __ERC4626_init(_asset);
        isPaused = false;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20Upgradeable(asset()).balanceOf(address(dao()));
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (isPaused) revert ContractPaused();

        SafeERC20Upgradeable.safeTransferFrom({
            token: IERC20Upgradeable(asset()),
            from: caller,
            to: address(dao()),
            value: assets
        });

        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        _withdrawFromDao(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _withdrawFromDao(address to, uint256 assets) internal {
        IDAO.Action[] memory action = new IDAO.Action[](1);
        action[0] = IDAO.Action({
            to: asset(),
            value: 0,
            data: abi.encodeCall(IERC20Upgradeable.transfer, (to, assets))
        });

        // this plugin must have Execute permission on the vault
        dao().execute({
            // The target contract
            _callId: bytes32(abi.encodePacked(to, assets, ++nonce)),
            // The array of actions the DAO will execute
            _actions: action,
            // are any of the transactions allowed to fail? 0 === none
            _allowFailureMap: 0
        });
    }
}

```

# Part 2: Plugin Setup

```typescript
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {VaultPlugin} from "./VaultPlugin.sol";

contract VaultPluginSetup is PluginSetup {
    address private immutable IMPLEMEMTATION;

    constructor() {
        IMPLEMEMTATION = address(new VaultPlugin());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes memory _data
    ) external returns (address plugin, PreparedSetupData memory preparedSetupData) {
        // 1. Decode Installation Data
		// 2. deploy plugin
        // 3. create permissions
        // 4. return permissions
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external pure returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        // 1. prepare permissions
        // 2. return permissions
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return IMPLEMEMTATION;
    }
}
```

## `prepareInstallation()`

```typescript
// 1. Decode Installation Data
    address asset = abi.decode(_data, (address));
```

```typescript
// 2. deploy plugin
plugin = createERC1967Proxy(
  IMPLEMEMTATION,
  abi.encodeCall(VaultPlugin.initialize, (IDAO(_dao), IERC20MetadataUpgradeable(asset)))
);
```

```typescript
// 3. create permissions
    PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](2);
```

```typescript
permissions[0] = PermissionLib.MultiTargetPermission({
  operation: PermissionLib.Operation.Grant,
  where: _dao,
  who: plugin,
  condition: PermissionLib.NO_CONDITION,
  permissionId: keccak256('EXECUTE_PERMISSION'),
});

permissions[1] = PermissionLib.MultiTargetPermission({
  operation: PermissionLib.Operation.Grant,
  where: plugin,
  who: _dao,
  condition: PermissionLib.NO_CONDITION,
  permissionId: keccak256('PAUSE_PERMISSION'),
});

// 4. return permissions
preparedSetupData.permissions = permissions;
```

## `prepareUninstallation()`

```typescript
function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external pure returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        permissions = new PermissionLib.MultiTargetPermission[](2);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _dao,
            who: _payload.plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: keccak256("PAUSE_PERMISSION")
        });
```

## Metadata

inside `build-metadata.json` update the input

```json
"inputs": [
        {
          "internalType": "address",
          "name": "asset",
          "type": "address",
          "description": "Vault base asset address"
        }
      ]
```

also update the `release-metadata.json`

```json
{
  "name": "Vault Plugin",
  "description": "ERC4626 vault plugin",
  "images": {}
}
```
