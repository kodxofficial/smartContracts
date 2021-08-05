pragma solidity ^0.5.10;
// SPDX-License-Identifier: MIT
import "./ownable.sol";
contract activable is ownable {
    bool maintainance;
    address activator;
    bool activate;

    modifier isActivator {
        require(msg.sender == activator,"XXYou are not contract activator.XX");
        _;
    }

    modifier isActivated {
        require(activate,"XXContract is not activated.XX");
        _;
    }

    modifier maintainanceOn {
        require(maintainance,"XXThe contract is not in maintainance mode.XX");
        _;
    }

    modifier maintainanceOff {
        require(! maintainance,"XXThe contract is in maintainance mode.XX");
        _;
    }

    constructor() public {
        maintainance = true;
        activator = msg.sender;
        activate = true;
    }

    function setActive() public isActivator maintainanceOn {
        maintainance = false;
    }

    function setInactive() public isActivator maintainanceOff {
        maintainance = true;
    }

    function setActivated(uint8 _activate) public isActivator {
        require((_activate > 0) != activate, "XXNew value required.XX");
        activate = (_activate > 0);
    }

    function getActivate() public view returns(bool) {
        return (activate);
    }

    function setActivator(address _activator) public isActivator {
        require(_activator != activator, "XXNew value required.XX");
        activator = _activator;
    }

    function getActivator() public view isOwner returns(address) {
        return (activator);
    }

    function getMaintainance() public view returns(bool) {
        return (maintainance);
    }

}