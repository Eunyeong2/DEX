// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../src/dex.sol";

contract dex_en_Test is Test{
    DEXsol Dex1;
    ERC20Mintable token1;
    ERC20Mintable token2;

    address internal nara = address(1);
    address internal summer = address(2);
    address internal enong = address(3);
    address internal hee = address(4);
    address internal hyun = address(5);

    constructor(){
        token1 = new ERC20Mintable("ENONG1", "ENO1");
        token2 = new ERC20Mintable("ENONG2", "ENO2");

        pair = new DEXsol(address(token1), address(token2));
        token1._mint(nara, 100);
        token2._mint(nara, 200);

        token1._mint(summer, 300);
        token2._mint(summer, 50);

        token1._mint(enong, 200);
        token2._mint(enong, 0);

        token1._mint(hee, 0);
        token2._mint(hee, 200);
        
        token1._mint(hyun, 0);
        token2._mint(hyun, 0);
    }

    function FirstAddLiquidity() public {
        vm.prank(nara);
        token1.approve(address(nara, 100));
        token2.approve(address(nara, 200));
        
        Dex1.addLiquidity(40, 30, 0);


    }
}