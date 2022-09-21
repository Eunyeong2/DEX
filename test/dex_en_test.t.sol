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

    address internal spring = address(1);
    address internal summer = address(2);
    address internal fall = address(3);
    address internal winter = address(4);
    address internal hee = address(5);

    function setUp() public{
        token1 = new ERC20Mintable("ENONG1", "EN1");
        token2 = new ERC20Mintable("ENONG2", "EN2");

        Dex1 = new DEXsol(address(token1), address(token2));

        token1.mint(spring, 200);
        token2.mint(spring, 200);

        token1.mint(summer, 300);
        token2.mint(summer, 50);

        token1.mint(fall, 200);
        token2.mint(fall, 0);

        token1.mint(winter, 0);
        token2.mint(winter, 200);
        
        token1.mint(hee, 0);
        token2.mint(hee, 0);
    }

    function testFirstAddLiquidity() public {
        vm.startPrank(spring);
        token1.approve(address(Dex1), 100);
        //vm.prank(spring);
        token2.approve(address(Dex1), 100);
        
        Dex1.addLiquidity(100, 100, 0);

        assertEq(Dex1.balanceOf(spring), 100); //lptoken 개수
        assertEq(token1.balanceOf(spring), 100); // 200개 중에 100개 넣음 -> 100
        assertEq(token2.balanceOf(spring), 100); // 200개 중에 100개 넣음 -> 100 

        assertEq(token1.balanceOf(address(Dex1)), 100); //풀에 들어있는 token1의 개수 : 100개
        assertEq(token2.balanceOf(address(Dex1)), 100); // 풀에 들어있는 token2의 개수 : 100개
    }

    function testFailFirstAddLiauidity() public {
        vm.startPrank(spring);
        token1.approve(address(Dex1), 100);
        token2.approve(address(Dex1), 100);

        Dex1.addLiquidity(100, 50, 0);
        vm.expectRevert("The proportion is broken");
    }

    function testRemoveLiquidity() public {
        testFirstAddLiquidity();

        //vm.prank(spring);
        Dex1.removeLiquidity(50, 0, 0);
        
        assertEq(token1.balanceOf(address(spring)), 150); //spring의 token0 잔고 + 다시 돌려받은 토큰 수
        assertEq(token2.balanceOf(address(spring)), 150);
    }
    
    function testSwap() public{
        testFirstAddLiquidity();
        
    }
    receive() external payable {}
}