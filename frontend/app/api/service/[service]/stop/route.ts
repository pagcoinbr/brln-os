import { NextRequest, NextResponse } from "next/server";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ service: string }> }
) {
  const { service } = await params;

  // Map service names to actual systemd service names
  const serviceMap: { [key: string]: string } = {
    lnbits: "lnbits.service",
    thunderhub: "thunderhub.service",
    simple: "simple-lnwallet.service",
    lndg: "lndg.service",
    "lndg-controller": "lndg-controller.service",
    lnd: "lnd.service",
    bitcoind: "bitcoind.service",
    "bos-telegram": "bos-telegram.service",
    tor: "tor.service",
  };

  const actualServiceName = serviceMap[service] || `${service}.service`;

  try {
    await execAsync(`sudo systemctl stop ${actualServiceName}`);

    return NextResponse.json({
      success: true,
      message: `Service ${service} stopped successfully`,
    });
  } catch (error) {
    return NextResponse.json(
      {
        success: false,
        message: `Failed to stop service ${service}: ${error}`,
      },
      { status: 500 }
    );
  }
}
