import { task } from "hardhat/config";
import * as dotenv from "dotenv";
import { loggedSafeExecTx } from "../lib/helpers";
import { defaultAbiCoder, Interface, parseEther } from "ethers/lib/utils";

dotenv.config();

task("call", "Call arbitrary function of any contract")
    .addParam("addr", "Contract address")
    .addParam("sig", "Function signature (replace spaces with +)")
    .addOptionalParam("value", "ETH value to pay", "0")
    .addOptionalVariadicPositionalParam("args", "Arguments for function call", [])
    .setAction(async ({addr, sig, value, args}, hre) => {
        sig = sig.split('+').join(' ');
        console.log(sig);
        
        const contract = await hre.ethers.getContractAt([`function ${sig}`], addr ?? "");

        const val = parseEther(value);
        if (!val.isZero()) {
            await loggedSafeExecTx(contract, Object.keys(contract.functions)[0], ...args, {value: parseEther(value)});
        } else {
            await loggedSafeExecTx(contract, Object.keys(contract.functions)[0], ...args);
        }
    });