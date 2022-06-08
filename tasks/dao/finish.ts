import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";

dotenv.config();

task("dao-finish-proposal", "Finish proposal and execute result")
    .addParam("id", "Id of proposal")
    .setAction(async ({id}, hre) => {
        const dao = await hre.ethers.getContractAt("DAO", process.env.DAO ?? "");

        await loggedSafeExecTx(dao, "finishProposal", id);
    });