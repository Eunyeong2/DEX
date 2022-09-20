// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../src/dex.sol";
//import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract DexEnTest is Test{
    DEXsol public Dex1;
    ERC20Mintable public token1;
    ERC20Mintable public token2;
    DEXsol public token;

    address internal nara = address(1);
    address internal summer = address(2);
    address internal enong = address(3);
    address internal hee = address(4);
    address internal hyun = address(5);

    function setUp() public{
        token1 = new ERC20Mintable("ENONG1", "EN1");
        token2 = new ERC20Mintable("ENONG2", "EN2");

        token = new DEXsol(address(token1), address(token2));

        token1.mint(nara, 100);
        token2.mint(nara, 200);

        token1.mint(summer, 300);
        token2.mint(summer, 50);

        token1.mint(enong, 200);
        token2.mint(enong, 0);

        token1.mint(hee, 0);
        token2.mint(hee, 200);
        
        token1.mint(hyun, 0);
        token2.mint(hyun, 0);
    }

    function FirstAddLiquidity() public {
        vm.prank(nara);
        token1.approve(address(token), 100);
        vm.prank(nara);
        token2.approve(address(token), 200);
        
        Dex1.addLiquidity(100, 100, 0);

        assertEq(Dex1.balanceOf(nara), 100); //lptoken 개수
        assertEq(token1.balanceOf(nara), 0); // 100개 중에 100개 넣음 -> 0
        assertEq(token2.balanceOf(nara), 100); // 200개 중에 100개 넣음 -> 100 

        assertEq(token1.balanceOf(address(Dex1)), 100); //풀에 들어있는 token1의 개수 : 100개
        assertEq(token2.balanceOf(address(Dex1)), 100); // 풀에 들어있는 token2의 개수 : 100개
    }

    receive() external payable {}
}