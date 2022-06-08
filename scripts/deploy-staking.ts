import * as hre from "hardhat";
import { ethers } from "hardhat";
import { deployLogged } from "../lib/helpers";
import * as dotenv from "dotenv";
import "hardhat-test-utils";
import { parseUnits } from "ethers/lib/utils";
const {time} = hre.testUtils;

dotenv.config();


async function main() {
  await deployLogged(
      hre, 
      "Staking", 
      process.env.LIQUIDITY_TOKEN, 
      process.env.XXX_TOKEN, 
      time.duration.days(7), 
      time.duration.days(10), 
      parseUnits("0.03", 18), 
      18);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
