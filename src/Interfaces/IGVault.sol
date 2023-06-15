// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// GVault interface
interface IGVault {

    function excessDebt(address _strategy)
        external
        view
        returns (uint256, uint256);

    function getStrategyDebt() external view returns (uint256);

    function creditAvailable() external view returns (uint256);

    function report(
        uint256 _gain,
        uint256 _loss,
        uint256 _debtRepayment,
        bool _emergency
    ) external returns (uint256);

    function getStrategyData()
        external
        view
        returns (
            bool,
            uint256,
            uint256
        );

    function transferOwnership(address newOwner) external;

    function setVaultFee(uint256 _fee) external;

    function vaultFee() external view returns (uint256);
}
