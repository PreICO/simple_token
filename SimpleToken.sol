/* Simple token - simple token for PreICO and ICO
   Copyright (C) 2017  Sergey Sherkunov <leinlawun@leinlawun.org>

   This file is part of simple token.

   Token is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

pragma solidity ^0.4.18;

import {SafeMath} from "SafeMath.sol";
import {Minter} from "Minter.sol";

contract SimpleToken {
    using SafeMath for uint256;

    address public owner;

    Minter public minter;

    string public name;

    string public symbol;

    uint8 public decimals;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed oldTokensHolder,
                   address indexed newTokensHolder, uint256 tokensNumber);

    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    event Transfer(address indexed tokensSpender,
                   address indexed oldTokensHolder,
                   address indexed newTokensHolder, uint256 tokensNumber);

    event Approval(address indexed tokensHolder, address indexed tokensSpender,
                   uint256 newTokensNumber);

    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    event Approval(address indexed tokensHolder, address indexed tokensSpender,
                   uint256 oldTokensNumber, uint256 newTokensNumber);

    modifier onlyOwner {
        require(owner == msg.sender);

        _;
    }

    modifier onlyMinter {
        require(minter == msg.sender);

        _;
    }

    //https://vessenes.com/the-erc20-short-address-attack-explained
    //https://blog.golemproject.net/how-to-find-10m-by-just-reading-blockchain-6ae9d39fcd95
    //https://ericrafaloff.com/analyzing-the-erc20-short-address-attack
    modifier checkPayloadSize(uint256 size) {
        require(msg.data.length == size + 4);

        _;
    }

    function SimpleToken(address _owner, Minter _minter, string _name,
                         string _symbol, uint8 _decimals) public {
        owner = _owner;
        minter = _minter;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setMinter(Minter _minter) public onlyOwner {
        uint256 _allowance = allowance[this][minter];

        _approve(this, minter, 0);

        minter = _minter;

        _approve(this, minter, _allowance);
    }

    function _transfer(address oldTokensHolder, address newTokensHolder,
                       uint256 tokensNumber) private {
        balanceOf[oldTokensHolder] =
            balanceOf[oldTokensHolder].sub(tokensNumber);

        balanceOf[newTokensHolder] =
            balanceOf[newTokensHolder].add(tokensNumber);

        Transfer(oldTokensHolder, newTokensHolder, tokensNumber);
    }

    //https://vessenes.com/the-erc20-short-address-attack-explained
    //https://blog.golemproject.net/how-to-find-10m-by-just-reading-blockchain-6ae9d39fcd95
    //https://ericrafaloff.com/analyzing-the-erc20-short-address-attack
    function transfer(address newTokensHolder, uint256 tokensNumber) public
                     checkPayloadSize(2 * 32) returns(bool success) {
        _transfer(msg.sender, newTokensHolder, tokensNumber);

        success = true;
    }

    //https://vessenes.com/the-erc20-short-address-attack-explained
    //https://blog.golemproject.net/how-to-find-10m-by-just-reading-blockchain-6ae9d39fcd95
    //https://ericrafaloff.com/analyzing-the-erc20-short-address-attack
    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function transferFrom(address oldTokensHolder, address newTokensHolder,
                          uint256 tokensNumber) public checkPayloadSize(3 * 32)
                         returns(bool success) {
        allowance[oldTokensHolder][msg.sender] =
            allowance[oldTokensHolder][msg.sender].sub(tokensNumber);

        _transfer(oldTokensHolder, newTokensHolder, tokensNumber);

        Transfer(msg.sender, oldTokensHolder, newTokensHolder, tokensNumber);

        success = true;
    }

    function _approve(address tokensHolder, address tokensSpender,
                      uint256 newTokensNumber) private {
        allowance[tokensHolder][tokensSpender] = newTokensNumber;

        Approval(msg.sender, tokensSpender, newTokensNumber);
    }

    //https://vessenes.com/the-erc20-short-address-attack-explained
    //https://blog.golemproject.net/how-to-find-10m-by-just-reading-blockchain-6ae9d39fcd95
    //https://ericrafaloff.com/analyzing-the-erc20-short-address-attack
    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address tokensSpender, uint256 newTokensNumber) public
                    checkPayloadSize(2 * 32) returns(bool success) {
        require(allowance[msg.sender][tokensSpender] == 0 ||
                newTokensNumber == 0);

        _approve(msg.sender, tokensSpender, newTokensNumber);

        success = true;
    }

    //https://vessenes.com/the-erc20-short-address-attack-explained
    //https://blog.golemproject.net/how-to-find-10m-by-just-reading-blockchain-6ae9d39fcd95
    //https://ericrafaloff.com/analyzing-the-erc20-short-address-attack
    //https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address tokensSpender, uint256 oldTokensNumber,
                     uint256 newTokensNumber) public checkPayloadSize(3 * 32)
                    returns(bool success) {
        require(allowance[msg.sender][tokensSpender] == oldTokensNumber);

        _approve(msg.sender, tokensSpender, newTokensNumber);

        Approval(msg.sender, tokensSpender, oldTokensNumber, newTokensNumber);

        success = true;
    }

    function mint(uint256 tokensNumber) public onlyMinter {
        totalSupply = totalSupply.add(tokensNumber);

        balanceOf[this] = balanceOf[this].add(tokensNumber);

        uint256 _allowance = allowance[this][msg.sender].add(tokensNumber);

        _approve(this, minter, _allowance);
    }
}
