import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";
import { parseEther } from "ethers/lib/utils";

dotenv.config();

task("platform-redeem-order", "Redeem order and buy tokens")
    .addParam("id", "Order id")
    .addParam("eth", "Amount of ETH to pay for token")
    .setAction(async ({id, eth}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "redeemOrder", id, {value: parseEther(eth)});
    });