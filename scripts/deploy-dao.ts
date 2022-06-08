import * as hre from "hardhat";
import { ethers } from "hardhat";
import { deployLogged } from "../lib/helpers";
import * as dotenv from "dotenv";
import "hardhat-test-utils";
import { parseUnits } from "ethers/lib/utils";
const {time} = hre.testUtils;

dotenv.config();


async function main() {
  await deployLogged(hre, "DAO", await ethers.provider.getSigner().getAddress(), parseUnits("1000", 18), time.duration.days(3));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
