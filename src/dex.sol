//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract DEXsol is IERC20, ERC20, ERC20Mintable {
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint public k; //reserve0*reserve1 (x*y=k)

    uint256 private _totalSupply;
    uint256 private _LpAmount;
    
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    uint private unlocked = 1;
    
    constructor(string memory _token0, string memory _token1) ERC20("Eunong LPToken", "LPT") { 
        token0 = _token0;
        token1 = _token1;
        factory = msg.sender;
    }
    
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    //event Mint(address indexed sender, uint amount0, uint amount1);
    //event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    //event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to);
    
    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external lock {
        if (tokenXAmount > tokenYAmount){ //tokenYAmount가 0일 때, token1로 스왑
            address I_Token = token0;
            address O_Token = token1;
            uint256 I_Amount = tokenXAmount;
            uint256 O_Amount = tokenYAmount;
            require(I_Amount > reserve0, "tokenXAmount exceeds X's reserve amount");
            _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        } else{ //tokenXAmount가 0일 때, token0으로 스왑
            address I_Token = token1;
            address O_Token = token0;
            uint256 I_Amount = tokenYAmount;
            uint256 O_Amount = tokenXAmount;
            require(O_Amount > reserve1, "tokenXAmount exceeds Y's reserve amount");
            _swap(I_Token, O_Token, I_Amount, O_Amount, tokenMinimumOutputAmount);
        }
    }

    function _swap(address I_Token, address O_Token, uint256 I_Amount, uint256 O_Amount, uint256 minimum ) internal lock returns (uint256 outputAmount){
        require(I_Amount != 0 && O_Amount == 0, "One token is must to be zero");

        uint reserve0 = IERC20(I_Token).balanceOf(address(this));
        uint reserve1 = IERC20(O_Token).balanceOf(address(this));

        //uint112 n_token1;
        //uint112 n_token2;
        uint256 exper; //exchange percentage
        exper = reserve0 / (reserve1 + O_Amount);
        
        transfer(address(I_Token), I_Amount); // I_token에 수수료 빼고 전송
        //transfer(address(this), tokenYmount); // lq pool에 token 넣기
        transferFrom(I_Token, address(this), (I_Amount - I_Amount/10)); // 수수료 납부
        transfer(address(O_Token), (O_Amount - O_Amount/10));

    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external lock {
        //require(tokenXAmount)
        //require(token1.transferFrom(msg.sender, address(this), tokenXAmount), "Transfer of token1 failed");
        //require(token2.transferFrom(msg.sender, address(this), tokenYAmount), "Transfer of token2 failed");
        //require(tokenXAmount > balanceof(msg.sender), "Exceeded tokenXAmount");
        if (tokenXAmount > tokenYAmount){ //tokenYAmount가 0일 때, token1로 스왑
            address I_Token = token0;
            address O_Token = token1;
            uint256 I_Amount = tokenXAmount;
            uint256 O_Amount = tokenYAmount;
            _addLiquidity(I_Token, O_Token, I_Amount, O_Amount, minimumLPTokenAmount);
        } else{ //tokenXAmount가 0일 때, token0으로 스왑
            address I_Token = token1;
            address O_Token = token0;
            uint256 I_Amount = tokenYAmount;
            uint256 O_Amount = tokenXAmount;
            _addLiquidity(I_Token, O_Token, I_Amount, O_Amount);
        }
    }

    function _addLiquidity(uint256 I_Token, address O_Token, uint256 I_Amount, uint256 O_Amount, uint256 minimum) internal lock returns (uint LPTokenAmount){
        require(I_Amount != 0 && O_Amount == 0, "One token is must to be zero");
        //LPTokenAmount = mint(msg.sender); //lp token 새로 mint
        
        uint reserve0 = IERC20(I_Token).balanceOf(address(this));
        uint reserve1 = IERC20(O_Token).balanceOf(address(this));

        k = (reserve0+I_Amount) * (reserve1+O_Amount);

        _totalSupply = totalSupply();

        if (_totalSupply == 0){
            _LpAmount = Math.sqrt(I_Amount.mul(O_Amount)).sub(MINIMUM_LIQUIDITY);
        } else{
            _LpAmount = Math.min(I_Amount.mul(_totalSupply) / reserve0, O_Amount.mul(_totalSupply) / reserve1 );
        }
        
        require(_LpAmount > 0, "LpAmount is zero");
        require(_LpAmount > minimum, "Lack of LPTokenAmount");
        _mint(address(this), _LpAmount);
        LPTokenAmount = _LpAmount;
        k = reserve0 * reserve1;
        //emit Mint(msg.sender, I_Amount, O_Amount);
    }

    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external lock {
        //(uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint reserve0 = IERC20(token0).balanceOf(address(this)); //pool에 있는 token 개수
        uint reserve1 = IERC20(token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)]; // liquidity

        uint _totalSupply = totalSupply(); //총 lptoken 개수
        uint amount0 = liquidity.mul(reserve0) / _totalSupply; //lptoken 만큼 수수료를 나눠줌
        uint amount1 = liquidity.mul(reserve1) / _totalSupply;
        
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_REMOVED");
        _burn(address(this), liquidity);
        transfer(token0, LPTokenAmount);
        transfer(token1, LPTokenAmount);

        reserve0 = IERC20(token0).balanceOf(address(this));
        reserve1 = IERC20(token1).balanceOf(address(this));

        //_update(balance0, balance1, _reserve0, _reserve1);
        //emit Burn(msg.sender, amount0, amount1, to);
    }

    //function transfer(address to, uint256 lpAmount) external returns (bool){
    //    transfer( msg.sender, to, lpAmount);
    //    return true;
    //}
}