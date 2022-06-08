import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";

dotenv.config();

task("platform-start-sale", "Start sale round (for admin)")
    .setAction(async ({}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "startSaleRound");
    });