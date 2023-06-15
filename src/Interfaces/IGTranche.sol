// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IGTranche {
    function deposit(
        uint256 _amount,
        uint256 _index,
        bool _tranche,
        address recipient
    ) external returns (uint256, uint256);

    function withdraw(
        uint256 _amount,
        uint256 _index,
        bool _tranche,
        address recipient
    ) external returns (uint256, uint256);

    function utilisationThreshold() external view returns (uint256);

    function setUtilisationThreshold(uint256 _newThreshold) external;

    function transferOwnership(address newOwner) external;
}
