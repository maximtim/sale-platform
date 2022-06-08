import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";
import { parseEther } from "ethers/lib/utils";

dotenv.config();

task("platform-remove-order", "Remove order and withdraw tokens")
    .addParam("id", "Order id")
    .setAction(async ({id}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "removeOrder", id);
    });