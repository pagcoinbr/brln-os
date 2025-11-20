import { NextRequest, NextResponse } from "next/server";
import { readFile, stat } from "fs/promises";
import { existsSync } from "fs";

export async function GET() {
  try {
    const flagPath = "/tmp/update_available.flag";

    if (!existsSync(flagPath)) {
      return NextResponse.json({
        novidade: false,
        timestamp: null,
      });
    }

    const fileStats = await stat(flagPath);
    const timestamp = fileStats.mtime.getTime().toString();

    return NextResponse.json({
      novidade: true,
      timestamp: timestamp,
    });
  } catch (error) {
    console.error("Error checking novidade status:", error);
    return NextResponse.json({
      novidade: false,
      timestamp: null,
    });
  }
}
