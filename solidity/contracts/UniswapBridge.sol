// SPDX-License-Identifier: GPL-2.0-only
// Copyright 2020 Spilsbury Holdings Ltd
pragma solidity >=0.6.6 <0.8.0;
pragma experimental ABIEncoderV2;

import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {UniswapV2Library} from '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import {IUniswapV2Router02} from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IDefiBridge} from './interfaces/IDefiBridge.sol';
import {Types} from './Types.sol';

// import 'hardhat/console.sol';

contract UniswapBridge is IDefiBridge {
    using SafeMath for uint256;

    address public immutable defiBridgeProxy;
    address public weth;

    IUniswapV2Router02 router;

    constructor(address _defiBridgeProxy, address _router) public {
        defiBridgeProxy = _defiBridgeProxy;
        router = IUniswapV2Router02(_router);
        weth = router.WETH();
    }

    receive() external payable {}

    function convert(
        Types.AztecAsset[4] calldata assets,
        uint64 auxData,
        uint256,
        uint256 inputValue
    )
        external
        payable
        override
        returns (
            uint256 outputValueA,
            uint256,
            bool isAsync
        )
    {
        require(msg.sender == defiBridgeProxy, 'UniswapBridge: INVALID_CALLER');
        require(auxData <= 1000,"UniswapBridge: Invalid_AuxData");
        // DONE This should check the pair exists on UNISWAP instead of blindly trying to swap.

        address[] memory path = new address[](2);
        uint amountOut;
        if (assets[0].assetType == Types.AztecAssetType.ETH && assets[2].assetType == Types.AztecAssetType.ERC20) {
            path[0] = weth;
            path[1] = assets[2].erc20Address;
            if(!checkPair(path[0],path[1])){
                return 
            }
            amountOut = router.getAmountsOut(inputValue, path)[1];
            // Assuming 0 fee for swapping(otherwise we will multiply 997 and then divide by 1000)
            // Slipage is in 0.1 then auxData will be 100
            amountOut = amountOut - (amountOut * auxData) /1000
            outputValueA = router.swapExactETHForTokens{value: inputValue}(amountOut, path, defiBridgeProxy, block.timestamp)[1];
            isAsync = true;
        } else if (
            assets[0].assetType == Types.AztecAssetType.ERC20 && assets[2].assetType == Types.AztecAssetType.ETH
        ) {
            path[0] = assets[0].erc20Address;
            path[1] = weth;
            if(!checkPair(path[0],path[1])){
                return 
            }
            amountOut = router.getAmountsOut(inputValue, path)[1];

            amountOut = amountOut - (amountOut * auxData) /1000
            require(
                IERC20(assets[0].erc20Address).approve(address(router), inputValue),
                'UniswapBridge: APPROVE_FAILED'
            );
            outputValueA = router.swapExactTokensForETH(inputValue, amountOut, path, defiBridgeProxy, block.timestamp)[1];
            isAsync = true;
        } else {
            // TODO what about swapping tokens?

            path[0] = assets[0].erc20Address;
            path[1] = assets[2].erc20Address;
            if(!checkPair(path[0],path[1])){
                return 
            }
            require(
                IERC20(path[0]).approve(address(router), inputValue),
                'UniswapBridge: APPROVE_FAILED'
            );
            amountOut = router.getAmountsOut(inputValue, path)[1];
            // Assuming 0 fee for swapping(otherwise we will multiply 997 and then divide by 1000)
            // Slipage is in 0.1 then auxData will be 100
            amountOut = amountOut - (amountOut * auxData) /1000
            outputValueA = router.swapExactTokensForTokens(inputValue, amountOut, path, defiBridgeProxy, block.timestamp)[1];
            isAsync = true;
        }
    }

    function canFinalise(
        Types.AztecAsset[4] calldata,
        uint64,
        uint256
    ) external view override returns (bool) {
        return false;
    }

    function checkPair(address token0,address token1) internal view returns(bool){
        address pair= IUniswapV2Factory(router.factory()).getPair(token0,token1);
        if(pair != address(0)){
            return true;
        }
    }

    function finalise(
        Types.AztecAsset[4] calldata,
        uint64,
        uint256
    ) external payable override returns (uint256, uint256) {
        require(false);
    }
}
