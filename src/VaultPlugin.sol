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
