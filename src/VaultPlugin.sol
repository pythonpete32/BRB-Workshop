// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {PluginUUPSUpgradeable, IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {ERC4626Upgradeable, ERC20Upgradeable, IERC20MetadataUpgradeable, SafeERC20Upgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract VaultPlugin is PluginUUPSUpgradeable, ERC4626Upgradeable {
    /// @notice Initializes the plugin when build 1 is installed.
    /// @param _asset Set the underlying asset contract.
    function initialize(IDAO _dao, IERC20MetadataUpgradeable _asset) external initializer {
        __PluginUUPSUpgradeable_init(_dao);
        __ERC4626_init(_asset);
    }

    /// @notice Returns the total assets held by the DAO
    /// @dev See {IERC4626-totalAssets}.
    function totalAssets() public view virtual override returns (uint256) {
        return IERC20MetadataUpgradeable(asset()).balanceOf(address(dao()));
    }

    /// @notice Overrides the _deposit function from the ERC4626 contract to deposit assets into the DAO instead of this
    /// contract.
    /// @dev See {IERC4626-_deposit}.
    /// @param caller The address of the caller.
    /// @param receiver The address of the receiver.
    /// @param assets The amount of assets to deposit.
    /// @param shares The amount of shares to issue.
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        SafeERC20Upgradeable.safeTransferFrom({
            token: IERC20Upgradeable(asset()),
            from: caller,
            to: address(dao()),
            value: assets
        });
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /// @notice Overrides the _withdraw function from the ERC4626 contract to withdraw assets from the DAO instead of
    /// this contract.
    /// @dev See {IERC4626-_withdraw}.
    /// @param caller The address of the caller.
    /// @param receiver The address of the receiver.
    /// @param owner The address of the owner.
    /// @param assets The amount of assets to withdraw.
    /// @param shares The amount of shares to burn.
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

    /// @notice Overrides the transfer function from the ERC20Upgradeable contract.
    /// @dev See {IERC4626-transfer}. This override is necessary to ensure that transfers are only
    /// allowed when they are enabled.
    function transfer(
        address to,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /// @dev Withdraws the specified amount of assets from the DAO to the specified address.
    /// @param to The address to transfer the assets to.
    /// @param assets The amount of assets to withdraw.
    function _withdrawFromDao(address to, uint256 assets) internal {
        // Create a new action to be executed by the DAO
        IDAO.Action[] memory action = new IDAO.Action[](1);
        action[0] = IDAO.Action({
            to: asset(),
            value: 0,
            data: abi.encodeWithSignature("transfer(address,uint256)", to, assets)
        });
        // Execute the action
        dao().execute({
            _callId: bytes32(abi.encodePacked(to, assets)),
            _actions: action,
            _allowFailureMap: 0
        });
    }
}
