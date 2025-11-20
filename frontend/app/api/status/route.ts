import { NextResponse } from "next/server";
import { exec } from "child_process";
import { promisify } from "util";
import { readFile } from "fs/promises";

const execAsync = promisify(exec);

async function getCpuUsage(): Promise<string> {
  try {
    const { stdout } = await execAsync(
      "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4 \"%\"}'"
    );
    return stdout.trim();
  } catch {
    return "N/A";
  }
}

async function getRamUsage(): Promise<string> {
  try {
    const { stdout } = await execAsync(
      "free -h | awk '/Mem:/ {print $3 \"/\" $2}'"
    );
    return stdout.trim();
  } catch {
    return "N/A";
  }
}

async function checkService(serviceName: string): Promise<string> {
  try {
    const { stdout } = await execAsync(`systemctl is-active ${serviceName}`);
    return stdout.trim() === "active" ? "ativo" : "inativo";
  } catch {
    return "inativo";
  }
}

async function getBlockchainStatus(): Promise<string> {
  try {
    const confPath = "/data/lnd/lnd.conf";
    const content = await readFile(confPath, "utf-8");

    if (content.includes("bitcoind.rpchost=bitcoin.br-ln.com:8085")) {
      return "Remoto";
    } else if (content.includes("#bitcoind.rpchost=bitcoin.br-ln.com:8085")) {
      return "Local";
    } else {
      return "Desconhecida";
    }
  } catch {
    return "Desconhecida";
  }
}

export async function GET() {
  try {
    const [cpu, ram, lnd, bitcoind, tor, blockchain] = await Promise.all([
      getCpuUsage(),
      getRamUsage(),
      checkService("lnd"),
      checkService("bitcoind"),
      checkService("tor"),
      getBlockchainStatus(),
    ]);

    const status = [
      `CPU: ${cpu}`,
      `RAM: ${ram}`,
      `LND: ${lnd}`,
      `Bitcoind: ${bitcoind}`,
      `Tor: ${tor}`,
      `Blockchain: ${blockchain}`,
    ].join("\n");

    return new NextResponse(status, {
      status: 200,
      headers: {
        "Content-Type": "text/plain",
      },
    });
  } catch (error) {
    console.error("Error fetching system status:", error);
    return new NextResponse("Error fetching system status", {
      status: 500,
    });
  }
}
