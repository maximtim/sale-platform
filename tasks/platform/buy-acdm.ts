import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";
import { parseEther } from "ethers/lib/utils";

dotenv.config();

task("platform-buy-acdm", "Buy token on sale round")
    .addParam("eth", "Amount of ETH to pay for token")
    .setAction(async ({eth}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "buyACDM", {value: parseEther(eth)});
    });