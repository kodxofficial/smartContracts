pragma solidity ^0.5.10;
// SPDX-License-Identifier: MIT
interface TRC20Token {
    function name() external view returns(string memory);
    function symbol() external view returns(string memory);
    function decimals() external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function balanceOf(address _owner) external view returns(uint256);
    function transfer(address _to, uint256 _value) external returns(bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns(bool success);
    function approve(address _spender, uint256 _value) external returns(bool);
    function allowance(address _owner, address _spender) external view returns(uint256);
}
