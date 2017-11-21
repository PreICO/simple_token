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
import {SimpleToken} from "SimpleMath.sol";

contract Minter {
    using SafeMath for uint256;

    enum MinterState {
        PreICOWait,
        PreICOStarted,
        ICOWait,
        ICOStarted,
        Over
    }

    struct Tokensale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokensMinimumNumberForBuy;
        uint256 tokensCost;
        uint256 tokensNumberForMint;
        bool tokensMinted;
        uint256 tokensStepOneBountyTime;
        uint256 tokensStepTwoBountyTime;
        uint256 tokensStepThreeBountyTime;
        uint256 tokensStepFourBountyTime;
        uint8 tokensStepOneBounty;
        uint8 tokensStepTwoBounty;
        uint8 tokensStepThreeBounty;
        uint8 tokensStepFourBounty;
    }

    address public owner;

    SimpleToken public token;

    Tokensale public PreICO;

    Tokensale public ICO;

    bool public paused = false;

    modifier onlyOwner {
        require(owner == msg.sender);

        _;
    }

    modifier onlyDuringTokensale {
        MinterState _minterState_ = _minterState();

        require(minterState == MinterState.PreICOStarted ||
                minterState == MinterState.ICOStarted);

        _;
    }

    modifier onlyAfterTokensaleOver {
        MinterState _minterState_ = _minterState();

        require(minterState == MinterState.Over);

        _;
    }

    modifier onlyNotPaused {
        require(!paused);

        _;
    }

    modifier checkLimitsToBuyTokens {
        MinterState minterState = _minterState();

        require(minterState == MinterState.PreICOStarted &&
                PreICO.tokensMinimumNumberForBuy <= msg.value /
                                                    PreICO.tokensCost ||
                minterState == MinterState.ICOStarted &&
                ICO.tokensMinimumNumberForBuy <= msg.value / ICO.tokensCost);

        _;
    }

    function Minter(string _name, string _symbol, uint8 _decimals) public {
        owner = msg.sender;
        token = new SimpleToken(owner, this, _name, _symbol, _decimals);
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    function _minterState() private constant returns(MinterState) {
        if(PreICO.startTime > now) {
            return MinterState.PreICOWait;
        } else if(PreICO.endTime > now) {
            return MinterState.PreICOStarted;
        } else if(ICO.startTime > now) {
            return MinterState.ICOWait;
        } else if(ICO.endTime > now) {
            return MinterState.ICOStarted;
        } else {
            return MinterState.Over;
        }
    }

    function _tokensaleCountTokensNumber(Tokensale tokensale,
                                         uint256 timestamp, uint256 wei,
                                         uint256 totalTokensNumber,
                                         uint256 totalTokensNumberAllowance)
                                        private pure returns(uint256, uint256) {
        uint256 tokensNumber = wei.div(tokensale.tokensCost);

        require(tokensNumber >= tokensale.tokensMinimumNumberForBuy);

        uint256 aviableTokensNumber =
            totalTokensNumber <= totalTokensNumberAllowance ?
                totalTokensNumber : totalTokensNumberAllowance;

        uint256 restWei = 0;

        if(tokensNumber >= aviableTokensNumber) {
            uint256 restTokensNumber = tokensNumber.sub(aviableTokensNumber);

            restWei = restTokensNumber.mul(tokensale.tokensCost);

            tokensNumber = aviableTokensNumber;
        } else {
            uint256 timePassed = timestamp.sub(tokensale.startTime);

            uint256 tokensNumberBounty = 0;

            if(timePassed < tokensale.tokensStepOneBountyTime) {
                tokensNumberBounty =
                    tokensNumber.mul(tokensale.tokensStepOneBounty).div(100);
            } else if(timePassed < tokensale.tokensStepTwoBountyTime) {
                tokensNumberBounty =
                    tokensNumber.mul(_tokensale.tokensStepTwoBounty).div(100);
            } else if(timePassed < tokensale.tokensStepThreeBountyTime) {
                tokensNumberBounty =
                    tokensNumber.mul(tokensale.tokensStepThreeBounty).div(100);
            } else if(timePassed < _tokensale.tokensStepFourBountyTime) {
                tokensNumberBounty =
                    tokensNumber.mul(tokensale.tokensStepFourBounty).div(100);
            }

            tokensNumber = tokensNumber.add(tokensNumberBounty);

            if(tokensNumber > aviableTokensNumber) {
                tokensNumber = aviableTokensNumber;
            }
        }

        return (tokensNumber, restWei);
    }

    function _tokensaleStart(Tokensale storage tokensale) private {
        if(!tokensale.tokensMinted) {
            token.mint(tokensale.tokensNumberForMint);

            tokensale.tokensMinted = true;
        }

        uint256 totalTokensNumber = token.balanceOf(token);

        uint256 totalTokensNumberAllowance = token.allowance(token, this);

        var (tokensNumber, restWei) =
            _tokensaleCountTokensNumber(tokensale, now, msg.value,
                                        totalTokensNumber,
                                        totalTokensNumberAllowance);

        token.transferFrom(token, msg.sender, tokensNumber);

        msg.sender.transfer(restWei);
    }

    function _tokensaleSelect() private constant returns(Tokensale storage) {
        MinterState minterState = _minterState();

        if(minterState == MinterState.PreICOStarted) {
            return PreICO;
        } else if (minterState == MinterState.ICOStarted) {
            return ICO;
        } else {
            revert();
        }
    }

    function withdraw() public onlyOwner {
        msg.sender.transfer(this.balance);
    }

    function () public payable onlyDuringTokensale onlyNotPaused
                checkLimitsToBuyTokens {
        Tokensale storage tokensale = _tokensaleSelect();

        _tokensaleStart(tokensale);
    }
}
