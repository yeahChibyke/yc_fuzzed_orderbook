// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OrderBook} from "../../src/OrderBook.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";
import {MockWETH} from "../mocks/MockWETH.sol";
import {MockWSOL} from "../mocks/MockWSOL.sol";
import "./utils/StdCheats.sol";
import {PropertiesAsserts} from "./utils/PropertiesHelper.sol";

contract FuzzBook is PropertiesAsserts {
    OrderBook book;

    MockUSDC usdc;
    MockWBTC wbtc;
    MockWETH weth;
    MockWSOL wsol;
    StdCheats cheats = StdCheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address clara = address(0x4);
    address dan = address(0x5);

    uint256 initialUSDCInBook;
    uint256 initialWBTCInBook;
    uint256 initialWETHInBook;
    uint256 initialWSOLInBook;
    uint256 max_deadline;

    uint64 mintAmount;

    constructor() {
        usdc = new MockUSDC(6);
        wbtc = new MockWBTC(8);
        weth = new MockWETH(18);
        wsol = new MockWSOL(18);

        cheats.prank(owner);
        book = new OrderBook(address(weth), address(wbtc), address(wsol), address(usdc), owner);

        mintAmount = type(uint64).max;

        wbtc.mint(alice, uint256(mintAmount));
        weth.mint(bob, uint256(mintAmount));
        wsol.mint(clara, uint256(mintAmount));
        usdc.mint(dan, uint256(mintAmount));

        cheats.prank(alice);
        wbtc.approve(address(book), uint256(mintAmount));

        cheats.prank(bob);
        weth.approve(address(book), uint256(mintAmount));

        cheats.prank(clara);
        wsol.approve(address(book), uint256(mintAmount));

        cheats.prank(dan);
        usdc.approve(address(book), uint256(mintAmount));
    }

    // function level invariants
    // OrderBook balance must increase by number of tokens used by sellers to create order
    function createSellOrder(uint256 amount) public {
        amount = clampBetween(amount, 1, uint256(mintAmount));

        initialWBTCInBook = wbtc.balanceOf(address(book));
        initialWETHInBook = weth.balanceOf(address(book));
        initialWSOLInBook = wsol.balanceOf(address(book));

        cheats.prank(alice);
        book.createSellOrder(address(wbtc), amount, 180_000e6, 2 days);

        cheats.prank(bob);
        book.createSellOrder(address(weth), amount, 9_000e6, 2 days);

        cheats.prank(clara);
        book.createSellOrder(address(wsol), amount, 400e6, 2 days);

        uint256 finalWBTCInBook = wbtc.balanceOf(address(book));
        assert((finalWBTCInBook - initialWBTCInBook) == amount);

        uint256 finalWETHInBook = weth.balanceOf(address(book));
        assert((finalWETHInBook - initialWETHInBook) == amount);

        uint256 finalWSOLInBook = wsol.balanceOf(address(book));
        assert((finalWSOLInBook - initialWSOLInBook) == amount);
    }

    function buySellOrder(uint256 sellAmount, uint256 buyAmount) public {
        sellAmount = clampBetween(sellAmount, 1, uint256(mintAmount));
        buyAmount = clampBetween(buyAmount, 1, uint256(mintAmount));
        cheats.prank(alice);

        initialWBTCInBook = wbtc.balanceOf(address(book));
        uint256 initialAliceWBTC = wbtc.balanceOf(alice);
        // uint256 initialAliceUSDC = usdc.balanceOf(alice);

        cheats.prank(alice);
        uint256 id = book.createSellOrder(address(wbtc), sellAmount, buyAmount, 2 days);

        uint256 finalWBTCInBook = wbtc.balanceOf(address(book));
        uint256 finalAliceWBTC = wbtc.balanceOf(alice);

        assert((finalWBTCInBook - initialWBTCInBook) == sellAmount);
        assert((initialAliceWBTC - finalAliceWBTC) == sellAmount);

        uint256 initialDanUSDC = usdc.balanceOf(dan);
        uint256 initialDanWBTC = wbtc.balanceOf(dan);

        cheats.prank(dan);
        book.buyOrder(id);

        uint256 finalDanUSDC = usdc.balanceOf(dan);
        uint256 finalDanWBTC = wbtc.balanceOf(dan);

        assert((initialDanUSDC - finalDanUSDC) == sellAmount);
        assert((finalDanWBTC - initialDanWBTC) == buyAmount);
    }
}
