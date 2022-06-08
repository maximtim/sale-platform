import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";

dotenv.config();

task("platform-register", "Vote in DAO")
    .addParam("id", "Id of proposal")
    .setAction(async ({id, votefor}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");

        await loggedSafeExecTx(platform, "vote", id, votefor === "true");
    });