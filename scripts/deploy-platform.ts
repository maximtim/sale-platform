import * as hre from "hardhat";
import { ethers } from "hardhat";
import { deployLogged } from "../lib/helpers";
import * as dotenv from "dotenv";
import "hardhat-test-utils";
const {time} = hre.testUtils;

dotenv.config();


async function main() {
  await deployLogged(hre, "ACDMPlatform", process.env.ACDM_TOKEN, time.duration.days(3));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
