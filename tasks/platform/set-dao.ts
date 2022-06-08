import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";

dotenv.config();

task("platform-set-dao", "Set DAO for platform")
    .addParam("dao", "Address of DAO")
    .setAction(async ({dao}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "setDAO", dao);
    });