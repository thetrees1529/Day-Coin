//SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/IJoeRouter01.sol";
import "./utils/IJoeFactory.sol";
import "./utils/DateTime.sol";

contract DayFactory {
    function createNewDay(DayFactory newDayFactory, uint newLifespan, uint newToLP, uint newDay, uint newDeadAt, Day newParent, IJoeRouter01 newRouter) external payable returns(Day day) {
        day = new Day(newDayFactory, newLifespan, newToLP, newDay, newDeadAt, newParent, newRouter);
        day.addLiquidity{value: msg.value}();
    }
}

contract Day is ERC20("","") {
    using Strings for uint;
    using DateTime for uint;

    uint public lifeSpan;
    uint public toLP;
    uint public day;
    Day public parent;
    uint public deadAt;
    bool public dead;
    bool public liquidityAdded;

    IJoeRouter01 public router;
    DayFactory public dayFactory;
    Day public child;
    mapping(address => bool) private _balanceCarried;

    constructor(DayFactory newDayFactory, uint newLifespan, uint newToLP, uint newDay, uint newDeadAt, Day newParent, IJoeRouter01 newRouter) payable {
        lifeSpan = newLifespan;
        toLP = newToLP;
        day = newDay;
        parent = newParent;
        router = newRouter;
        dayFactory = newDayFactory;
        deadAt = newDeadAt;
    }

    function symbol() public view override returns(string memory) {
        return string.concat("DAY ", day.toString());
    }

    function addLiquidity() public payable {
        require(!liquidityAdded, "Day: liquidity already added");
        _mint(address(this), toLP);
        _approve(address(this), address(router), toLP);
        router.addLiquidityAVAX{value: msg.value}(address(this), toLP, toLP, msg.value, address(this), block.timestamp);
        liquidityAdded = true;
    }

    function name() public view override returns(string memory) {
        (, , , uint hour, uint minute, uint second) = deadAt.timestampToDateTime();
        return string.concat(symbol(),
            "... THIS COIN WILL MIGRATE AT ",
            hour.toString(),":", minute.toString(),":", second.toString(),' UTC. Once this time has been reached, new trades are disallowed, and anyone will be able to trigger the migrate by sending themselves 0 tokens. If you hold through this time, your balance will be reflected in the new token with a 10% bonus. Treat this as a compound. In this new token you must make a transfer involving yourself before that day ends in order to carry your balance over to the next migration. How many migrations will you compound for?');
    }

    function balanceOf(address addr) public view override returns(uint) {
        uint main = super.balanceOf(addr);
        return _balanceCarried[addr] ? main : main + _carriedBalanceOf(addr);
    }

    function _isKillable() private view returns(bool) {
        return block.timestamp >= deadAt && !dead;
    }

    function _hasParent() private view returns(bool) {
        return parent != Day(payable(address(0)));
    }

    function _transfer(address from, address to, uint value) internal override {
        require(!dead, "Day: dead");
        _carryBalanceIfNotCarried(from);
        _carryBalanceIfNotCarried(to);
        super._transfer(from, to, value);
        if(_isKillable() && !_isKilling) _kill();
    }

    function _carriedBalanceOf(address addr) private view returns(uint) {
        if(!_hasParent()) return 0;
        return (parent.balanceOf(addr) * 11) / 10;
    }

    function _carryBalanceIfNotCarried(address addr) private {
        if(!_balanceCarried[addr]) {
            _balanceCarried[addr] = true;
            _mint(addr, _carriedBalanceOf(addr));
        }
    }

    function _newDay() private view returns(uint) {
        return day + 1;
    }

    bool private _isKilling;

    receive() external payable {require(_isKilling, "Day: not killing");}

    function _kill() private {
        _isKilling = true;

        address pair = IJoeFactory(router.factory()).getPair(address(this), router.WAVAX());
        IERC20 token = IERC20(pair);
        token.approve(address(router), type(uint).max);
        uint toRemove = token.balanceOf(address(this));
        router.removeLiquidityAVAX(address(this), toRemove, 0, 0, address(this), block.timestamp);

        dead = true;
        _isKilling = false;

        child = dayFactory.createNewDay{value: address(this).balance}(dayFactory, lifeSpan, toLP, _newDay(), block.timestamp + lifeSpan, this, router);
    }   

}
