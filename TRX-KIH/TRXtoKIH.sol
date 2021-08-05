pragma solidity ^0.5.10;
// SPDX-License-Identifier: MIT
import "./SafeMath.sol";
import "./activable.sol";
import "./iTRC20.sol";

contract TRXtoTokenPool is activable {
    using SafeMath for uint;
//****************************************************************************
//* Data
//****************************************************************************
    struct Token {
        address tokenAddress;
        string tokenSymbol;
        uint tokenDecimals;
        TRC20Token trc20Token;
    }
//    Token freezeToken;
    Token gainToken;
    uint changeFactor;
    uint changeDivisor;
    uint yearlyGainPercent;
    uint investedValue = 0;
    uint gainValue;
    uint withdrawal = 0;
    uint lastUpdate = now;
    uint unfreezeGap = 1 seconds;
    struct User {
        uint investedValue;
        uint unfreezableValue;
        uint gainValue;
        uint lastUpdate;
        uint Withdrawal;
        uint freezeTime;
    }
    mapping(address => User) users;
    address[] usersArray;
    uint feePercent = 5; // 5%
    uint feeBalance = 0;
    uint totalFee = 0;
//****************************************************************************
//* Modifiers
//****************************************************************************
    modifier isRegsistered(address _user) {
        require(users[_user].lastUpdate > 0,"XXUser is not registered.XX");
        _;
    }

//****************************************************************************
//* Events
//****************************************************************************
    event Freeze(address _user, uint _value);
    event Unfreeze(address _user, uint _value);
    event Withdrew(address _user, uint _value);
//****************************************************************************
//* Main Functions
//****************************************************************************
    constructor() public {

    }
/*
    function setFreezeToken(address _tokenAddress) public isActivator {
        require(_tokenAddress != address(0),"XXToken address is not valid.XX");
        require(freezeToken.tokenAddress == address(0),"XXInvalid address.XX");
        TRC20Token _trc20Token = TRC20Token(_tokenAddress);
        string memory _tokenSymbol = _trc20Token.symbol();
        uint _tokenDecimals = _trc20Token.decimals();
        freezeToken = Token({
            tokenAddress: _tokenAddress,
            tokenSymbol: _tokenSymbol,
            tokenDecimals: _tokenDecimals,
            trc20Token: _trc20Token
        });
    }
*/
    function setGainToken(address _tokenAddress) public isActivator {
        require(_tokenAddress != address(0),"XXToken address is not valid.XX");
        require(gainToken.tokenAddress == address(0),"XXInvalid addressXX");
        TRC20Token _trc20Token = TRC20Token(_tokenAddress);
        string memory _tokenSymbol = _trc20Token.symbol();
        uint _tokenDecimals = _trc20Token.decimals();
        gainToken = Token({
            tokenAddress: _tokenAddress,
            tokenSymbol: _tokenSymbol,
            tokenDecimals: _tokenDecimals,
            trc20Token: _trc20Token
        });
    }

    function setYearlyGain(uint _yearlyGain) public isOwner {
        require(yearlyGainPercent != _yearlyGain,"XXYou must set a new value.XX");
        yearlyGainPercent = _yearlyGain;
    }
    
    function setFeePercent(uint _feePercent) public isOwner {
        require(_feePercent >= 0 && _feePercent < 100,"XXInvalid fee percent.XX");
        require(_feePercent != feePercent,"XXYou must set a new value.XX");
        feePercent = _feePercent;
    }
    
    function withdrawGainToken(uint _value) public isOwner {
        require(_value <= gainToken.trc20Token.balanceOf(address(this)),"XXValue is greater than balance.XX");
        gainToken.trc20Token.transfer(owner, _value);
    }

    function freeze() public payable maintainanceOff isActivated {
        uint _value = msg.value;
        require(_value > 0,"XXYou must pay TRX.XX");
        uint _fee = _value.mul(feePercent).div(100);
        feeBalance = feeBalance.add(_fee);
        totalFee = totalFee.add(_fee);
        if (users[msg.sender].lastUpdate == 0) {
            users[msg.sender] = User({
                investedValue: _value,
                unfreezableValue: _value.sub(_fee),
                gainValue: 0,
                lastUpdate: now,
                Withdrawal: 0,
                freezeTime: now
            });
            investedValue = investedValue.add(_value);
        } else {
            User storage _user = users[msg.sender];
            uint _gain = getGain(_user.investedValue, _user.lastUpdate);
            _user.gainValue = _gain.add(_user.gainValue);
            _user.investedValue = _user.investedValue.add(_value);
            _user.unfreezableValue = _user.unfreezableValue.add(_value).sub(_fee);
            _user.lastUpdate = now;
            _user.freezeTime = now;
            investedValue = investedValue.add(_value);
            gainValue = gainValue.add(_gain);
            lastUpdate = now;
        }
        emit Freeze(msg.sender, _value);
    }

    function withdrawGain(uint _value) public isRegsistered(msg.sender) maintainanceOff isActivated {
        User storage _user = users[msg.sender];
        uint _gain = getGain(_user.investedValue, _user.lastUpdate);
        uint _totalGain = _gain.add(_user.gainValue);
        _value = _value.min(gainToken.trc20Token.balanceOf(address(this)));
        require(_value <= _user.investedValue.add(_totalGain),"XXWithdraw value is not present.XX");
        require(_value <= _totalGain,"XXThis gain is not present.XX");
        _user.gainValue = _totalGain.sub(_value);
        gainValue = gainValue.add(_gain).sub(_value);
        _user.lastUpdate = now;
        _user.Withdrawal = _user.Withdrawal.add(_value);
        lastUpdate = now;
        withdrawal = withdrawal.add(_value);
        gainToken.trc20Token.transfer(msg.sender, _value);
        emit Withdrew(msg.sender, _value);
    }

    function unfreeze(uint _value) public isRegsistered(msg.sender) maintainanceOff isActivated {
        User storage _user = users[msg.sender];
        require(_value <= _user.unfreezableValue,"XXThis amount is not unfreezable.XX");
        require(now.sub(_user.freezeTime) >= unfreezeGap,"XXUnfreez gap time is not expired.XX");
        uint _gain = getGain(_user.investedValue, _user.lastUpdate);
        _user.gainValue = _gain.add(_user.gainValue);
        _user.lastUpdate = now;
        lastUpdate = now;
        gainValue = gainValue.add(_gain);
        uint _investedValueDec = _value.mul(100).div(100-feePercent);
        investedValue = investedValue.sub(_investedValueDec);
        _user.investedValue = _user.investedValue.sub(_investedValueDec);
        _user.unfreezableValue = _user.unfreezableValue.sub(_value);
        msg.sender.transfer(_value);
        emit Unfreeze(msg.sender, _value);
    }
    
    function withdrawFee() public isOwner {
        require(feeBalance > 0,"XXFee balance is zero.XX");
        owner.transfer(feeBalance);
        feeBalance = 0;
    }

    function setChange(uint _changeFactor, uint _changeDivisor) public isOwner {
        require(_changeFactor != changeFactor || _changeDivisor != changeDivisor,"XXNew value required.XX");
        if (_changeFactor != changeFactor)
            changeFactor = _changeFactor;
        if (_changeDivisor != changeDivisor)
            changeDivisor = _changeDivisor;
    }

    function getGain(uint _investedValue, uint _lastUpdate) internal view returns(uint) {
        uint _gain = _investedValue.mul(changeFactor).div(changeDivisor).mul(yearlyGainPercent).div(100).mul(now.sub(_lastUpdate)).div(31536000); //365*86400
        return(_gain);
    }

//****************************************************************************
//* Getter Functions
//****************************************************************************
    function getMyInvest() public view isRegsistered(msg.sender) returns(uint) {
        return(users[msg.sender].investedValue);
    }

    function getMyUnfreezable() public view isRegsistered(msg.sender) returns(uint) {
        return(users[msg.sender].unfreezableValue);
    }

    function getMyGain() public view isRegsistered(msg.sender) returns(uint) {
        User memory _user = users[msg.sender];
        return(getGain(_user.investedValue, _user.lastUpdate).add(_user.gainValue));
    }

    function getMyLastUpdate() public view isRegsistered(msg.sender) returns(uint) {
        return(users[msg.sender].lastUpdate);
    }

    function getMyFreezeTime() public view isRegsistered(msg.sender) returns(uint) {
        return(users[msg.sender].freezeTime);
    }

    function getMyWithdrawal() public view isRegsistered(msg.sender) returns(uint) {
        return(users[msg.sender].Withdrawal);
    }

    function getUserInvest(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].investedValue);
    }

    function getUserUnfreezable(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].unfreezableValue);
    }

    function getUserGain(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].gainValue);
    }

    function getUserLastUpdate(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].lastUpdate);
    }

    function getUserWithdrawal(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].Withdrawal);
    }
    
    function getUserFreezeTime(address _user) public view isOwner isRegsistered(_user) returns(uint) {
        return(users[_user].freezeTime);
    }

    function getUserAddress(uint _userIndex) public view isOwner returns(address) {
        require(_userIndex < usersArray.length,"XXUser index is out of range.XX");
        return(usersArray[_userIndex]);
    }

    function getUnfreezeGap() public view returns(uint) {
        return(unfreezeGap);
    }

    function getUsersCount() public view isOwner returns(uint) {
        return(usersArray.length);
    }

    function getFreezeTronBalance() public view returns(uint) {
        return(address(this).balance);
    }

    function getGainTokenBalance() public view returns(uint) {
        return(gainToken.trc20Token.balanceOf(address(this)));
    }

    function getFreezeTokenInvest() public view returns(uint) {
        return(investedValue);
    }

    function getGainTokenGain() public view returns(uint) {
        return(gainValue);
    }

    function getTokenLastUpdate() public view returns(uint) {
        return(lastUpdate);
    }

    function getYearlyGainPercent() public view returns(uint) {
        return(yearlyGainPercent);
    }
/*
    function getFreezeTokenSymbol() public view returns(string memory) {
        return(freezeToken.tokenSymbol);
    }
*/
    function getGainTokenSymbol() public view returns(string memory) {
        return(gainToken.tokenSymbol);
    }
/*
    function getFreezeTokenAddress() public view returns(address) {
        return(freezeToken.tokenAddress);
    }
*/
    function getGainTokenAddress() public view returns(address) {
        return(gainToken.tokenAddress);
    }

    function getGainTokenWithdrawal() public view isOwner returns(uint) {
        return(withdrawal);
    }

    function getFeePercent() public view returns(uint) {
        return(feePercent);
    }
    
    function getFeeBalance() public view isOwner returns(uint) {
        return(feeBalance);
    }

    function getTotalFee() public view isOwner returns(uint) {
        return(totalFee);
    }

}