import { BigNumber } from "ethers";
import { parseUnits, parseEther, formatUnits, formatEther } from "ethers/lib/utils";
import { task } from "hardhat/config";
import { loggedSafeExecTx } from "../../lib/helpers";
import { IUniswapV2Router01 } from "../../typechain";

task("add-liquidity-eth", "Create pool (WETH-XXX) if it doesn't exist and add liquidity there")
  .addOptionalParam("needapprove", "Set to true if token needs approval to transfer (default=false)", "false")
  .addParam("amounteth")
  .addParam("amountxxx")
  .setAction(async ({needapprove, amounteth, amountxxx}, hre) => {
    const signer = await hre.ethers.provider.getSigner();
    const uniRouter = await hre.ethers.getContractAt("IUniswapV2Router01", process.env.UNISWAP_ROUTER ?? "");
    const xxxToken = await hre.ethers.getContractAt("IERC20", process.env.XXX_TOKEN ?? "");

    if (needapprove === "true") {
      await loggedSafeExecTx(xxxToken, "approve", uniRouter.address, parseUnits(amountxxx, 18));
    }

    await loggedSafeExecTx( 
      uniRouter,
      "addLiquidityETH",
      process.env.XXX_TOKEN ?? "",
      parseUnits(amountxxx, 18),
      0,
      0,
      await signer.getAddress(),
      Date.now() + 60*60*24,
      { value : parseEther(amounteth) }
    );
});