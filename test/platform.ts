import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import * as hre from "hardhat";
import { ethers } from "hardhat";
import { deploy, execTx } from "../lib/helpers";
import { ACDMPlatform, ACDMToken } from "../typechain";
import "hardhat-test-utils";
import { parseEther, parseUnits } from "ethers/lib/utils";
const {time, network, BN} = hre.testUtils;

describe("ACDMPlatform",async () => {
  let owner : SignerWithAddress,
     first: SignerWithAddress, 
     second: SignerWithAddress, 
     third : SignerWithAddress;
  let platform: ACDMPlatform;
  let token: ACDMToken;
  let snapshot: string;

  const ACDMs = (num: string) => parseUnits(num, 6);
  const XXXs = (num: string) => parseUnits(num, 18);

  beforeEach(async () => {
    snapshot = await network.snapshot();

    [ owner, first, second, third ] = await ethers.getSigners();

    const token0 = await deploy(hre, "ACDMToken");
    token = token0 as unknown as ACDMToken;

    const platform0 = await deploy(hre, "ACDMPlatform", token0.address, time.duration.days(3));
    platform = platform0 as unknown as ACDMPlatform;

    await execTx(token.grantRole(await token.MINTER_ROLE(), platform.address));
    await execTx(platform.connect(first).register(second.address));
    await execTx(platform.connect(second).register(third.address));
  });

  it("should deploy successfully",async () => {
    expect(platform.address).to.be.properAddress;
    expect(token.address).to.be.properAddress;

    expect(await platform.token()).to.eq(token.address);
    expect(await platform.currentRound()).to.eq(0);
    expect(await platform.referrers(first.address)).to.eq(second.address);
    expect(await platform.referrers(second.address)).to.eq(third.address);
  });

  it("should start sale round",async () => {
    await expect(platform.startSaleRound())
      .to.emit(platform, "SaleRoundStarted")
      .withArgs(parseEther("0.00001").div(10**6), parseEther("1"));

    expect(await platform.currentRound()).to.eq(1);
  });

  context("Sale round started",async () => {
    beforeEach(async () => {
      await execTx(platform.startSaleRound());
    });

    it("should sell ACDM to user",async () => {
      const buyAmount = ACDMs("1000");
      const weiValue = buyAmount.mul(await platform.currentSalePriceWei());
  
      expect(await token.balanceOf(first.address)).to.eq(0);
  
      await expect(platform.connect(first).buyACDM({value: weiValue}))
        .to.emit(platform, "TokenBought")
        .withArgs(first.address, buyAmount);
  
      expect(await token.balanceOf(first.address)).to.eq(buyAmount);
    });

    it("should sell ACDM and send remaining ETH back ",async () => {
      const buyAmount = ACDMs("1000000");
      const actualAmount = ACDMs("100000");
      const weiValue = buyAmount.mul(await platform.currentSalePriceWei());
  
      expect(await token.balanceOf(first.address)).to.eq(0);
      const balanceBefore = await first.getBalance();
  
      await expect(platform.connect(first).buyACDM({value: weiValue}))
        .to.emit(platform, "TokenBought")
        .withArgs(first.address, actualAmount);
  
      expect(await token.balanceOf(first.address)).to.eq(actualAmount);
      expect(balanceBefore.sub(await first.getBalance())).to.be.closeTo(parseEther("1"), parseEther("0.01"));
    });

    it("should sell and pay referrers",async () => {
      const buyAmount = ACDMs("1000");
      const weiValue = buyAmount.mul(await platform.currentSalePriceWei());
      const balance2Before = await second.getBalance();
      const balance3Before = await third.getBalance();
      const commission1 = weiValue.mul(await platform.referrer1SaleFracture()).div(await platform.fractureDenominator());
      const commission2 = weiValue.mul(await platform.referrer2SaleFracture()).div(await platform.fractureDenominator());

      await execTx(platform.connect(first).buyACDM({value: weiValue}));

      expect((await second.getBalance()).sub(balance2Before)).to.eq(commission1);
      expect((await third.getBalance()).sub(balance3Before)).to.eq(commission2);
    });

    context("Sale ended; Trade round started",async () => {
      beforeEach(async () => {
        const buyAmount = ACDMs("100000");
        const weiValue = buyAmount.mul(await platform.currentSalePriceWei());

        await execTx(platform.connect(first).buyACDM({value: weiValue}));

        await expect(platform.startTradeRound())
          .to.emit(platform, "TradeRoundStarted");
      });

      it("should start trade round",async () => {
        expect(await platform.currentRound()).to.eq(2);
      });

      it("should add order",async () => {
        const amount = ACDMs("1000");
        expect(await token.balanceOf(first.address)).to.eq(ACDMs("100000"));

        await execTx(token.connect(first).approve(platform.address, amount));

        await expect(platform.connect(first).addOrder(amount, parseEther("1")))
          .to.emit(platform, "OrderAdded")
          .withArgs(1, first.address, amount, parseEther("1"));

        expect(await token.balanceOf(first.address)).to.eq(ACDMs("99000"));
      });

      context("Added order",async () => {
        beforeEach(async () => {
          const amount = ACDMs("1000");
          const orderPrice = parseEther("1").div(10**6);
          expect(await token.balanceOf(first.address)).to.eq(ACDMs("100000"));

          await execTx(token.connect(first).approve(platform.address, amount));

          await expect(platform.connect(first).addOrder(amount, orderPrice))
            .to.emit(platform, "OrderAdded")
            .withArgs(1, first.address, amount, orderPrice);

          expect(await token.balanceOf(first.address)).to.eq(ACDMs("99000"));
        });

        it("should remove order",async () => {
          await expect(platform.connect(first).removeOrder(1))
            .to.emit(platform, "OrderRemoved")
            .withArgs(1);
  
          expect(await token.balanceOf(first.address)).to.eq(ACDMs("100000"));
        });

        it("should redeem order fully and send remaining ETH back",async () => {
          const buyAmount = ACDMs("10000");
          const actualAmount = ACDMs("1000");
          const weiValue = buyAmount.mul((await platform.orders(1)).priceWei);
          const actualSent = actualAmount.mul((await platform.orders(1)).priceWei);
          const ethBefore = await second.getBalance();

          await expect(platform.connect(second).redeemOrder(1, {value: weiValue}))
            .to.emit(platform, "OrderRedeemed")
            .withArgs(1, actualAmount);
  
          expect(await token.balanceOf(first.address)).to.eq(ACDMs("99000"));
          expect(await token.balanceOf(second.address)).to.eq(ACDMs("1000"));
          expect(ethBefore.sub(await second.getBalance())).to.be.closeTo(actualSent, parseEther("0.01"));
        });

        it("should redeem order partially",async () => {
          const buyAmount = ACDMs("100");
          const weiValue = buyAmount.mul((await platform.orders(1)).priceWei);
          const ethBefore = await second.getBalance();

          await expect(platform.connect(second).redeemOrder(1, {value: weiValue}))
            .to.emit(platform, "OrderRedeemed")
            .withArgs(1, buyAmount);
  
          expect(await token.balanceOf(first.address)).to.eq(ACDMs("99000"));
          expect(await token.balanceOf(second.address)).to.eq(ACDMs("100"));
          expect(ethBefore.sub(await second.getBalance())).to.be.closeTo(weiValue, parseEther("0.01"));
        });

        it.only("should redeem and pay referrers",async () => {
          const buyAmount = ACDMs("100");
          const weiValue = buyAmount.mul((await platform.orders(1)).priceWei);
          const balance2Before = await second.getBalance();
          const balance3Before = await third.getBalance();
          const commission1 = weiValue.mul(await platform.referrer1TradeFracture()).div(await platform.fractureDenominator());
          const commission2 = weiValue.mul(await platform.referrer2TradeFracture()).div(await platform.fractureDenominator());

          await execTx(platform.connect(first).redeemOrder(1, {value: weiValue}));
  
          expect(await token.balanceOf(first.address)).to.eq(ACDMs("99100"));
          expect((await second.getBalance()).sub(balance2Before)).to.eq(commission1);
          expect((await third.getBalance()).sub(balance3Before)).to.eq(commission2);
        });
      });

      
    });
  });

  afterEach(async () => {
    await network.revert(snapshot);
  });
});
