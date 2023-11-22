// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.17;

import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
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
        address asset = decodeInstallData(_data);

        plugin = createERC1967Proxy(
            IMPLEMEMTATION,
            abi.encodeWithSelector(VaultPlugin.initialize.selector, _dao, asset)
        );

        PermissionLib.MultiTargetPermission[]
            memory permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });

        preparedSetupData.permissions = permissions;
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external pure returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _dao,
            who: _payload.plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: keccak256("EXECUTE_PERMISSION")
        });
    }

    function encodeInstallData(address _asset) external pure returns (bytes memory) {
        return abi.encode(_asset);
    }

    function decodeInstallData(bytes memory _data) public pure returns (address asset) {
        return abi.decode(_data, (address));
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return IMPLEMEMTATION;
    }
}
