// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/forge-std/src/console.sol";

contract Dex is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 _tokenX;
    IERC20 _tokenY;

    uint public k;

    constructor(address tokenX, address tokenY) ERC20("DreamAcademy DEX LP token", "DA-DEX-LP") {
        require(tokenX != tokenY, "DA-DEX: Tokens should be different");

        _tokenX = IERC20(tokenX);
        _tokenY = IERC20(tokenY);
    }

    function transfer(address _to, uint _amount) override public returns (bool) {
        require(allowance(msg.sender, _to) >= _amount);
        transfer(_to, _amount);
    }
    
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount)
        external
        returns (uint256 outputAmount)
    {
        if (tokenXAmount > tokenYAmount){ //tokenYAmount가 0일 때, _tokenY로 스왑
            address I_Token = address(_tokenX);
            address O_Token = address(_tokenY);
            uint256 I_Amount = tokenXAmount;
            uint256 O_Amount = tokenYAmount;
            require(I_Amount <= IERC20(_tokenX).balanceOf(address(this)), "tokenXAmount exceeds X's reserve amount");
            outputAmount = _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        } else{ //tokenXAmount가 0일 때, _tokenX으로 스왑
            address I_Token = address(_tokenY);
            address O_Token = address(_tokenX);
            uint256 I_Amount = tokenYAmount;
            uint256 O_Amount = tokenXAmount;
            require(O_Amount <= IERC20(_tokenY).balanceOf(address(this)), "tokenYAmount exceeds Y's reserve amount");
            outputAmount = _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        }
    }

    function _swap(address I_Token, address O_Token, uint256 I_Amount, uint256 O_Amount, uint256 minimum ) internal returns (uint256 outputAmount){
        require(I_Amount != 0 && O_Amount == 0, "One token is must to be zero"); //I_Token -> O_Token, I_Amount 만큼. O_Amount는 0
        require(IERC20(I_Token).balanceOf(address(this)) >= I_Amount, "I_Token's balance is over the I_Amount");
        uint __reserve0 = IERC20(I_Token).balanceOf(address(this));
        uint __reserve1 = IERC20(O_Token).balanceOf(address(this));


        uint amount; // 수수료 
        amount = I_Amount * 1/1000; //수수료
        I_Amount = I_Amount - amount; //I_Amount - 수수료

        outputAmount = __reserve1 - k / (__reserve0 + I_Amount);

        IERC20(O_Token).transfer(msg.sender, outputAmount); //swap 할 때 생기는 가격 변동으로 인해 빠지는 금액
        IERC20(I_Token).transferFrom(msg.sender, address(this), I_Amount+amount); //수수료 뺀 토큰 주기

        require(O_Amount >= minimum, "outputAmount is under minimum");
    }

    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'INSUFFICIENT_LIQUIDITY');
        amountB = (amountA*reserveB) / reserveA;
    }


    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount)
        external
        returns (uint256 LPTokenAmount)
    {
        uint __reserve0 = IERC20(_tokenX).balanceOf(address(this));
        uint __reserve1 = IERC20(_tokenY).balanceOf(address(this));
 
        uint amount0 = tokenXAmount;
        uint amount1 = tokenYAmount;

         if ( totalSupply() == 0){ //처음 토큰을 넣을 때
             //require(tokenXAmount/tokenYAmount == 1, "The proportion is broken"); //비율을 1:1로 넣게 설정
             (amount0, amount1) = (tokenXAmount, tokenYAmount);
         } else{
            uint amountBO = quote(tokenXAmount, __reserve0, __reserve1); //비율 다시 계산
            if (amountBO <= tokenYAmount){ // 넣으려고 하는 Y token의 양이 비율과 맞지 않을 때
                require(amountBO >= minimumLPTokenAmount, 'INSUFFICIENT_B_AMOUNT');
                (amount0, amount1) = (tokenXAmount, amountBO); // 비율에 맞게 줄여버리기
            } else{
                uint amountAO = quote(tokenYAmount, __reserve1, __reserve0); // 넣으려는 X token의 양이 비율과 맞지 않을 때
                assert(amountAO <= tokenXAmount);
                require(amountAO >= minimumLPTokenAmount, 'INSUFFICIENT_A_AMOUNT');
                (amount0, amount1) = (amountAO, tokenYAmount); // 비율에 맞게 줄여버리기
            }
        }

        IERC20(_tokenX).transferFrom(msg.sender, address(this), amount0);
        IERC20(_tokenY).transferFrom(msg.sender, address(this), amount1);

        k = (__reserve0 + amount0) * (__reserve1 + amount1);

        if (totalSupply() == 0){ // 아직 발행 된 lp 토큰이 없을 때
            LPTokenAmount = sqrt(amount0*amount1); // 루트 k의 값으로 설정
        } else{
            LPTokenAmount = min(amount0*totalSupply() / __reserve0, amount1*totalSupply() / __reserve1);
        }

        require(LPTokenAmount > 0, "LPTokenAMount is under zero");
        require(LPTokenAmount >= minimumLPTokenAmount, "LPTokenAmount is under minimumLPTokenAmount");
        _mint(msg.sender, LPTokenAmount);
        console.log("LPToken :", LPTokenAmount);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount)
        external returns (uint256 transferX, uint256 transferY)
    {
        require(LPTokenAmount <= totalSupply(), "TotalSupply is under LPTokenAmount");
        uint __reserve0 = IERC20(_tokenX).balanceOf(address(this));
        uint __reserve1 = IERC20(_tokenY).balanceOf(address(this));
        
        transferX = (LPTokenAmount*__reserve0) / totalSupply(); //가지고 있는 lptoken 만큼 수수료를 나눠줌
        transferY = (LPTokenAmount*__reserve1) / totalSupply();
        
        require(transferX > 0 && transferY > 0, "Insufficient liquidity removed");
        require(transferX > minimumTokenXAmount && transferY > minimumTokenYAmount, "Amount is under minimum");

        _burn(msg.sender, LPTokenAmount);

        IERC20(_tokenX).transfer(msg.sender, transferX);
        IERC20(_tokenY).transfer(msg.sender, transferY);

        k = (__reserve0 - transferX) * (__reserve1 - transferY);
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

