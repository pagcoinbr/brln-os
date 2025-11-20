"use client";

import { useState, useEffect } from "react";

interface SystemStatusData {
  cpu: string;
  ram: string;
  lnd: string;
  bitcoind: string;
  tor: string;
  blockchain: string;
}

export default function SystemStatus() {
  const [status, setStatus] = useState<SystemStatusData>({
    cpu: "Carregando...",
    ram: "Carregando...",
    lnd: "Carregando...",
    bitcoind: "Carregando...",
    tor: "Carregando...",
    blockchain: "Carregando...",
  });

  const fetchStatus = async () => {
    try {
      const response = await fetch("/api/status");
      if (!response.ok) {
        throw new Error("Erro ao obter status do sistema.");
      }
      const text = await response.text();

      const lines = text.split("\n");
      const newStatus: Partial<SystemStatusData> = {};

      for (const line of lines) {
        if (line.includes("CPU:")) {
          newStatus.cpu = line;
        } else if (line.includes("RAM:")) {
          newStatus.ram = line;
        } else if (line.includes("LND:")) {
          newStatus.lnd = line;
        } else if (line.includes("Bitcoind:")) {
          newStatus.bitcoind = line;
        } else if (line.includes("Tor:")) {
          newStatus.tor = line;
        } else if (line.includes("Blockchain:")) {
          newStatus.blockchain = line;
        }
      }

      setStatus((prev) => ({ ...prev, ...newStatus }));
    } catch (error) {
      console.error("Erro ao atualizar status:", error);
    }
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <>
      <h2>📊 Status do Sistema</h2>
      <div className="status" id="cpu">
        {status.cpu}
      </div>
      <div className="status" id="ram">
        {status.ram}
      </div>
      <div className="status" id="lnd">
        {status.lnd}
      </div>
      <div className="status" id="bitcoind">
        {status.bitcoind}
      </div>
      <div className="status" id="tor">
        {status.tor}
      </div>
      <div className="status" id="blockchain">
        {status.blockchain}
      </div>
    </>
  );
}
