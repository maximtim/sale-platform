import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";

dotenv.config();

task("dao-set-staking", "Set staking, where DAO should get users vote weights")
    .addParam("staking", "Address of contract")
    .setAction(async ({staking}, hre) => {
        const dao = await hre.ethers.getContractAt("DAO", process.env.DAO ?? "");

        await loggedSafeExecTx(dao, "setDepositInfo", staking);
    });