//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract DEXsol is IERC20, ERC20 {

    address public token0;
    address public token1;

    uint256 private reserve0;
    uint256 private reserve1;

    uint public k; //reserve0*reserve1 (x*y=k)

    uint256 private _totalSupply;
    uint256 private _LpAmount;
    
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    uint private unlocked = 1;
    
    constructor(address _token0, address _token1) ERC20("Eunong LPToken", "LPT") { 
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }


    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external lock {
        if (tokenXAmount > tokenYAmount){ //tokenYAmount가 0일 때, token1로 스왑
            address I_Token = token0;
            address O_Token = token1;
            uint256 I_Amount = tokenXAmount;
            uint256 O_Amount = tokenYAmount;
            require(I_Amount <= IERC20(token0).balanceOf(address(this)), "tokenXAmount exceeds X's reserve amount");
            _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        } else{ //tokenXAmount가 0일 때, token0으로 스왑
            address I_Token = token1;
            address O_Token = token0;
            uint256 I_Amount = tokenYAmount;
            uint256 O_Amount = tokenXAmount;
            require(O_Amount <= IERC20(token1).balanceOf(address(this)), "tokenYAmount exceeds Y's reserve amount");
            _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        }
    }

    function _swap(address I_Token, address O_Token, uint256 I_Amount, uint256 O_Amount, uint256 minimum ) internal returns (uint256 outputAmount){
        require(I_Amount != 0 && O_Amount == 0, "One token is must to be zero"); //I_Token -> O_Token, I_Amount 만큼. O_Amount는 0

        uint __reserve0 = IERC20(I_Token).balanceOf(address(this));
        uint __reserve1 = IERC20(O_Token).balanceOf(address(this));


        uint amount; // 수수료 
        amount = I_Amount * 1/1000; //수수료
        I_Amount = I_Amount - amount; //I_Amount - 수수료


        IERC20(O_Token).transfer(msg.sender, __reserve1 - k / (__reserve0 + I_Amount)); //swap 할 때 생기는 가격 변동으로 인해 빠지는 금액
        IERC20(I_Token).transferFrom(msg.sender, address(this), I_Amount); //수수료 뺀 토큰 주기

        require(O_Amount >= minimum, "outputAmount is under minimum");
        outputAmount = O_Amount;
    }


    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'INSUFFICIENT_LIQUIDITY');
        amountB = (amountA*reserveB) / reserveA;
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external lock returns(uint LPTokenAmount) {
        require(IERC20(token0).balanceOf(msg.sender) >= tokenXAmount, "Checking balances");
        require(IERC20(token1).balanceOf(msg.sender) >= tokenYAmount, "Checking balances");
        uint __reserve0 = IERC20(token0).balanceOf(address(this));
        uint __reserve1 = IERC20(token1).balanceOf(address(this));
        uint amount0;
        uint amount1;

        if (__reserve0 == 0 && __reserve1 == 0){ //처음 토큰을 넣을 때
            require(tokenXAmount/tokenYAmount == 1, "The proportion is broken"); //비율을 1:1로 넣게 설정
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

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        k = (__reserve0 + amount0) * (__reserve1 + amount1);

        if (totalSupply() == 0){ // 아직 발행 된 lp 토큰이 없을 때
            LPTokenAmount = Math.sqrt(amount0*amount1); // 루트 k의 값으로 설정
        } else{
            LPTokenAmount = Math.min(amount0*totalSupply() / __reserve0, amount1*totalSupply() / __reserve1);
        }

        require(LPTokenAmount > 0, "LPTokenAMount is under zero");
        require(LPTokenAmount >= minimumLPTokenAmount, "LPTokenAmount is under minimumLPTokenAmount");
        _mint(msg.sender, LPTokenAmount);
    }

    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external lock {
        require(LPTokenAmount <= totalSupply(), "TotalSupply is under LPTokenAmount");
        uint __reserve0 = IERC20(token0).balanceOf(address(this));
        uint __reserve1 = IERC20(token1).balanceOf(address(this));
        
        uint amount0 = (LPTokenAmount*__reserve0) / totalSupply(); //가지고 있는 lptoken 만큼 수수료를 나눠줌
        uint amount1 = (LPTokenAmount*__reserve1) / totalSupply();
        
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity removed");
        require(amount0 > minimumTokenXAmount && amount1 > minimumTokenYAmount, "Amount is under minimum");

        _burn(msg.sender, LPTokenAmount);

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        k = (__reserve0 - amount0) * (__reserve1 - amount1);
    }
}