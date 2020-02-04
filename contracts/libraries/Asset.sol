pragma solidity >= 0.6.0;

import { MassDeposit, Withdrawable, Types } from "../libraries/Types.sol";
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


struct Asset {
    address erc20;
    address wallet;
}

library AssetHandler {
    /**
     * @dev It moves assets from layer 1 to the layer 2 anchor contract.
     */
    function depositFrom(Asset memory self, address from, uint amount) internal returns (bool) {
        if (self.erc20 == address(0)) {
            /// Asset is Ether
            require(amount == msg.value, "Does not receive correct amount");
            require(from == msg.sender, "Different sender");
        } else {
            /// Asset is ERC20
            IERC20(self.erc20).transferFrom(from, self.wallet, amount);
        }
        return true;
    }

    /**
     * @dev It withdraw assets back to the layer 1 from the layer 2 anchor contract.
     */
    function withdrawTo(Asset memory self, address to, uint amount) internal {
        if (self.erc20 == address(0)) {
            /// Asset is Ether
            payable(to).transfer(amount);
        } else {
            /// Asset is ERC20
            IERC20(self.erc20).transfer(to, amount);
        }
    }
}
