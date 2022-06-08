import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../../lib/helpers";
import { parseEther, parseUnits } from "ethers/lib/utils";

dotenv.config();

task("platform-add-order", "Add new ACDM order with custom amount and price")
    .addOptionalParam("needapprove", "Set to true if token needs approval to transfer (default=false)", "false")
    .addParam("amount", "ACDM amount")
    .addParam("price", "ETH price")
    .setAction(async ({needapprove, amount, price}, hre) => {
        const platform = await hre.ethers.getContractAt("ACDMPlatform", process.env.ACDM_PLATFORM ?? "");
        const acdmToken = await hre.ethers.getContractAt("IERC20", process.env.ACDM_TOKEN ?? "");

        if (needapprove === "true") {
            await loggedSafeExecTx(acdmToken, "approve", platform.address, parseUnits(amount, 6));
        }

        await loggedSafeExecTx(platform, "addOrder", parseUnits(amount, 6), parseEther(price));
    });