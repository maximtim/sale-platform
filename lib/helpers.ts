import { expect } from "chai";
import { Contract, ContractTransaction } from "ethers";
import { Interface } from "ethers/lib/utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export function delay(n : number){
  return new Promise(function(resolve){
      setTimeout(resolve,n*1000);
  });
}

export async function execTx(txPromise : Promise<ContractTransaction>) {
  const tx = await txPromise;
  return await tx.wait();
}

export async function expectTuple(txRes : Promise<any[]>, ...args : any[]) {
  const [...results] = await txRes;

  results.forEach((element, index) => {
    if (index >= args.length) return;
    expect(element).to.eq(args[index]);
  });
}

export async function loggedSafeExecTx(contract : Contract, funcName : string, ...args : any[]) {
  console.log("Starting", funcName, ":");
  
  const results = await contract.callStatic[funcName](...args);
  console.log("Callstatic success:", results);

  const txRes = await execTx(contract.functions[funcName](...args));
  console.log("Gas:", txRes.gasUsed.toString());

  const eventLogs = txRes.events?.map(ev => {
    let eventLog : { 
      signature : string,
      args : {[k: string] : string}
    } = {
      signature: ev.eventSignature!,
      args: {}
    };
    
    Object.keys(ev.args ?? {})
      .filter(k => isNaN(parseInt(k)))
      .forEach(key => {
        eventLog.args[key] = ev.args![key].toString();
      });
    return eventLog;
  });
  console.log("Txn hash:", txRes.transactionHash);
  console.log("Event logs:", eventLogs);
  console.log("Finished", funcName);
  // console.log("Event logs full:", txRes.events);
}

export async function deploy(hre : HardhatRuntimeEnvironment, contractName : string, ...args : any[]) {
  const Factory = await hre.ethers.getContractFactory(contractName);
  const contract = await Factory.deploy(...args);
  await contract.deployed();
  return contract;
}

export async function deployLogged(hre : HardhatRuntimeEnvironment, contractName : string, ...args : any[]) {
  const contract = await deploy(hre, contractName, ...args);
  console.log(contractName, "deployed to:", contract.address);
  return contract;
}

export const encodeFunctionCall = (func: string, args: any[]): string => {
  return new Interface([`function ${func}`]).encodeFunctionData(func, args);
};
