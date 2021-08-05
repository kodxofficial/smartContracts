pragma solidity ^0.5.10;
// SPDX-License-Identifier: MIT
import "./SafeMath.sol";
import "./activable.sol";
import "./iTRC20.sol";

contract KODXStaking is activable {
    using SafeMath for uint;
//****************************************************************************
//* Data
//****************************************************************************
    struct Token {
        address tokenAddress;
        string tokenSymbol;
        TRC20Token trc20Token;
        uint yearlyGainPercent;
        bool active;
        uint investedValue;
        uint gainValue;
        uint withdrawal;
        uint lastUpdate;
    }
    Token[] tokens;
    struct User {
        uint investedValue;
        uint gainValue;
        uint lastUpdate;
        uint Withdrawal;
    }
    struct UserToken {
        bool registered;
        mapping(uint => User) userToken;
    }
    mapping(address => UserToken) users;
    address[] usersArray;
//****************************************************************************
//* Modifiers
//****************************************************************************
    modifier isRegsistered(address _user) {
        require(users[_user].registered,"XXUser is not registered.XX");
        _;
    }

    modifier isToken(uint _tokenIndex) {
        require(_tokenIndex < tokens.length,"XXToken index is out of range.XX");
        _;
    }

    modifier isTokenActive(uint _tokenIndex) {
        checkToken(_tokenIndex);
        require(tokens[_tokenIndex].active,"XXToken is not active.XX");
        _;
    }

    modifier isTokenInactive(uint _tokenIndex) {
        checkToken(_tokenIndex);
        require(! tokens[_tokenIndex].active,"XXToken is active.XX");
        _;
    }
//****************************************************************************
//* Events
//****************************************************************************
    event TokenAdded(address _tokenAddress, uint _tokenIndex);
    event Invested(address _user, uint _tokenIndex, uint _value);
    event Reinvested(address _user, uint _tokenIndex, uint _value);
    event Withdrew(address _user, uint _tokenIndex, uint _value);
//****************************************************************************
//* Main Functions
//****************************************************************************
    function addToken(address _tokenAddress, uint _yearlyGain) public isActivator {
        require(_tokenAddress != address(0),"XXToken address is not valid.XX");
        TRC20Token _trc20Token = TRC20Token(_tokenAddress);
        string memory _tokenSymbol = _trc20Token.symbol();
        tokens.push(Token({
            tokenAddress: _tokenAddress,
            tokenSymbol: _tokenSymbol,
            trc20Token: _trc20Token,
            yearlyGainPercent: _yearlyGain,
            active: false,
            investedValue: 0,
            gainValue: 0,
            withdrawal: 0,
            lastUpdate: now
        }));
        emit TokenAdded(_tokenAddress, tokens.length.dec());
    }

    function setTokenActive(uint _tokenIndex) public isOwner isTokenInactive(_tokenIndex) {
        tokens[_tokenIndex].active = true;
    }

    function setTokenInactive(uint _tokenIndex) public isOwner isTokenActive(_tokenIndex) {
        tokens[_tokenIndex].active = false;
    }

    function setTokenGain(uint _tokenIndex, uint _yearlyGain) public isOwner isToken(_tokenIndex) {
        require(tokens[_tokenIndex].yearlyGainPercent != _yearlyGain,"XXYou must set a new value.XX");
        tokens[_tokenIndex].yearlyGainPercent = _yearlyGain;
    }

    function withdrawToken(uint _tokenIndex, uint _value) public isOwner isToken(_tokenIndex) {
        require(_value <= tokens[_tokenIndex].trc20Token.balanceOf(address(this)),"XXValue is greater than balance.XX");
        tokens[_tokenIndex].trc20Token.transfer(owner, _value);
    }

    function invest(uint _tokenIndex) public isToken(_tokenIndex) maintainanceOff isActivated {
        uint _value = tokens[_tokenIndex].trc20Token.allowance(msg.sender, address(this));
        require(_value > 0,"XXAllow function is not executed for the token.XX");
        tokens[_tokenIndex].trc20Token.transferFrom(msg.sender, address(this), _value);
        if (! users[msg.sender].registered) {
            usersArray.push(msg.sender);
            users[msg.sender] = UserToken({
                registered: true
            });
        }
        if (users[msg.sender].userToken[_tokenIndex].lastUpdate == 0) {
            users[msg.sender].userToken[_tokenIndex] = User({
                investedValue: _value,
                gainValue: 0,
                lastUpdate: now,
                Withdrawal: 0
            });
            tokens[_tokenIndex].investedValue = tokens[_tokenIndex].investedValue.add(_value);
        } else {
            User storage _user = users[msg.sender].userToken[_tokenIndex];
            uint _gain = getGain(_tokenIndex, _user.investedValue, _user.lastUpdate);
            _user.gainValue = _gain.add(_user.gainValue);
            _user.investedValue = _user.investedValue.add(_value);
            _user.lastUpdate = now;
            tokens[_tokenIndex].investedValue = tokens[_tokenIndex].investedValue.add(_value);
            tokens[_tokenIndex].gainValue = tokens[_tokenIndex].gainValue.add(_gain);
            tokens[_tokenIndex].lastUpdate = now;
        }
        emit Invested(msg.sender, _tokenIndex, _value);
    }

    function reinvest(uint _tokenIndex, uint _value) public isRegsistered(msg.sender) isToken(_tokenIndex) maintainanceOff isActivated {
        User storage _user = users[msg.sender].userToken[_tokenIndex];
        uint _gain = getGain(_tokenIndex, _user.investedValue, _user.lastUpdate);
        uint _totalGain = _gain.add(_user.gainValue);
        require(_value <= _totalGain,"XXReinvest value is not present.XX");
        _user.gainValue = _totalGain.sub(_value);
        _user.investedValue = _user.investedValue.add(_value);
        _user.lastUpdate = now;
        tokens[_tokenIndex].investedValue = tokens[_tokenIndex].investedValue.add(_value);
        tokens[_tokenIndex].gainValue = tokens[_tokenIndex].gainValue.add(_gain).sub(_value);
        tokens[_tokenIndex].lastUpdate = now;
        emit Reinvested(msg.sender, _tokenIndex, _value);
    }

    function withdraw(uint _tokenIndex, uint _value) public isRegsistered(msg.sender) isToken(_tokenIndex) maintainanceOff isActivated {
        User storage _user = users[msg.sender].userToken[_tokenIndex];
        uint _gain = getGain(_tokenIndex, _user.investedValue, _user.lastUpdate);
        uint _totalGain = _gain.add(_user.gainValue);
        _value = _value.min(tokens[_tokenIndex].trc20Token.balanceOf(address(this)));
        require(_value <= _user.investedValue.add(_totalGain),"XXWithdraw value is not present.XX");
        if (_value <= _totalGain) {
            _user.gainValue = _totalGain.sub(_value);
            tokens[_tokenIndex].gainValue = tokens[_tokenIndex].gainValue.add(_gain).sub(_value);
        } else {
            tokens[_tokenIndex].investedValue = tokens[_tokenIndex].investedValue.sub(_value.sub(_totalGain));
            tokens[_tokenIndex].gainValue = tokens[_tokenIndex].gainValue.sub(_user.gainValue);
            _user.gainValue = 0;
            _user.investedValue = _user.investedValue.sub(_value.sub(_totalGain));
        }
        _user.lastUpdate = now;
        _user.Withdrawal = _user.Withdrawal.add(_value);
        tokens[_tokenIndex].lastUpdate = now;
        tokens[_tokenIndex].withdrawal = tokens[_tokenIndex].withdrawal.add(_value);
        tokens[_tokenIndex].trc20Token.transfer(msg.sender, _value);
        emit Withdrew(msg.sender, _tokenIndex, _value);
    }

    function getGain(uint _tokenIndex, uint _investedValue, uint _lastUpdate) internal view returns(uint) {
        uint _gain = _investedValue.mul(tokens[_tokenIndex].yearlyGainPercent).div(100).mul(now.sub(_lastUpdate)).div(31536000); //365*86400
        return(_gain);
    }

    function checkToken(uint _tokenIndex) internal view isToken(_tokenIndex) {
    }

//****************************************************************************
//* Getter Functions
//****************************************************************************
    function getMyInvest(uint _tokenIndex) public view isRegsistered(msg.sender) isToken(_tokenIndex) returns(uint) {
        return(users[msg.sender].userToken[_tokenIndex].investedValue);
    }

    function getMyGain(uint _tokenIndex) public view isRegsistered(msg.sender) isToken(_tokenIndex) returns(uint) {
        User memory _user = users[msg.sender].userToken[_tokenIndex];
        return(getGain(_tokenIndex, _user.investedValue, _user.lastUpdate).add(_user.gainValue));
    }

    function getMyLastUpdate(uint _tokenIndex) public view isRegsistered(msg.sender) isToken(_tokenIndex) returns(uint) {
        return(users[msg.sender].userToken[_tokenIndex].lastUpdate);
    }

    function getMyWithdrawal(uint _tokenIndex) public view isRegsistered(msg.sender) isToken(_tokenIndex) returns(uint) {
        return(users[msg.sender].userToken[_tokenIndex].Withdrawal);
    }

    function getUserInvest(address _user, uint _tokenIndex) public view isOwner isRegsistered(_user) isToken(_tokenIndex) returns(uint) {
        return(users[_user].userToken[_tokenIndex].investedValue);
    }

    function getUserGain(address _user, uint _tokenIndex) public view isOwner isRegsistered(_user) isToken(_tokenIndex) returns(uint) {
        return(users[_user].userToken[_tokenIndex].gainValue);
    }

    function getUserLastUpdate(address _user, uint _tokenIndex) public view isOwner isRegsistered(_user) isToken(_tokenIndex) returns(uint) {
        return(users[_user].userToken[_tokenIndex].lastUpdate);
    }

    function getUserWithdrawal(address _user, uint _tokenIndex) public view isOwner isRegsistered(_user) isToken(_tokenIndex) returns(uint) {
        return(users[_user].userToken[_tokenIndex].Withdrawal);
    }

    function getUserAddress(uint _userIndex) public view isOwner returns(address) {
        require(_userIndex < usersArray.length,"XXUser index is out of range.XX");
        return(usersArray[_userIndex]);
    }

    function getUsersCount() public view isOwner returns(uint) {
        return(usersArray.length);
    }

    function getTokenBalance(uint _tokenIndex) public view isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].trc20Token.balanceOf(address(this)));
    }

    function getTokenInvest(uint _tokenIndex) public view isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].investedValue);
    }

    function getTokenGain(uint _tokenIndex) public view isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].gainValue);
    }

    function getTokenLastUpdate(uint _tokenIndex) public view isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].lastUpdate);
    }

    function getTokenYearlyGainPercent(uint _tokenIndex) public view isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].yearlyGainPercent);
    }

    function getTokenSymbol(uint _tokenIndex) public view isToken(_tokenIndex) returns(string memory) {
        return(tokens[_tokenIndex].tokenSymbol);
    }

    function getTokenAddress(uint _tokenIndex) public view isToken(_tokenIndex) returns(address) {
        return(tokens[_tokenIndex].tokenAddress);
    }

    function getTokenWithdrawal(uint _tokenIndex) public view isOwner isToken(_tokenIndex) returns(uint) {
        return(tokens[_tokenIndex].withdrawal);
    }

    function getTokenActive(uint _tokenIndex) public view isToken(_tokenIndex) returns(bool) {
        return(tokens[_tokenIndex].active);
    }

    function getTokenCount() public view returns(uint) {
        return(tokens.length);
    }

}