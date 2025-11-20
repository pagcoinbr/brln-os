import { NextRequest, NextResponse } from "next/server";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ service: string }> }
) {
  const { service } = await params;

  // Validate service name
  const validServices = [
    "lnbits",
    "thunderhub",
    "simple",
    "lndg",
    "lndg-controller",
    "lnd",
    "bitcoind",
    "bos-telegram",
    "tor",
  ];

  if (!validServices.includes(service)) {
    return NextResponse.json({ error: "Invalid service" }, { status: 400 });
  }

  try {
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
    const command = `systemctl is-active ${actualServiceName}`;

    const { stdout } = await execAsync(command);

    return NextResponse.json({
      service: actualServiceName,
      status: stdout.trim(),
    });
  } catch (error: any) {
    // If systemctl returns non-zero exit code, service is likely inactive
    return NextResponse.json({
      service,
      status: "inactive",
    });
  }
}
