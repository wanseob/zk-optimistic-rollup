pragma solidity >= 0.6.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

library Layer1 {
    function toLayer2(address self, address layer2, uint amount) internal returns (bool) {
        if(self == address(0)) {
            require(amount == msg.value, "Does not receive correct amount");
        } else {
            IERC20(self).transferFrom(self, layer2, amount);
        }
        return true;
    }

    function withdrawFromLayer2(address self, address to, uint amount) internal {
        if(self == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(self).transfer(to, amount);
        }
    }
}
