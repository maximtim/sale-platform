import * as hre from "hardhat";
import { ethers } from "hardhat";
import { deployLogged } from "../lib/helpers";
import * as dotenv from "dotenv";
import "hardhat-test-utils";
const {time} = hre.testUtils;

dotenv.config();


async function main() {
  await deployLogged(hre, "XXXToken");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});