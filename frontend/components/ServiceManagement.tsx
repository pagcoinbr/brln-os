"use client";

import { useState, useEffect } from "react";

export default function ServiceManagement() {
  const [services, setServices] = useState<{ [key: string]: string }>({});
  const [loading, setLoading] = useState<{ [key: string]: boolean }>({});

  const serviceList = [
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

  const serviceNames = {
    lnbits: "LNBits",
    thunderhub: "Thunderhub",
    simple: "Simple Wallet",
    lndg: "LNDg",
    "lndg-controller": "LNDg Controller",
    lnd: "LND",
    bitcoind: "Bitcoin Core",
    "bos-telegram": "BOS Telegram",
    tor: "Tor",
  };

  const fetchServiceStatus = async (service: string) => {
    try {
      const response = await fetch(`/api/service/${service}/status`);
      const data = await response.json();
      setServices((prev) => ({ ...prev, [service]: data.status }));
    } catch (error) {
      console.error(`Error fetching status for ${service}:`, error);
      setServices((prev) => ({ ...prev, [service]: "unknown" }));
    }
  };

  const toggleService = async (service: string, action: "start" | "stop") => {
    setLoading((prev) => ({ ...prev, [service]: true }));

    try {
      const response = await fetch(`/api/service/${service}/${action}`, {
        method: "POST",
      });

      if (response.ok) {
        // Wait a bit before checking status
        setTimeout(() => {
          fetchServiceStatus(service);
        }, 2000);
      }
    } catch (error) {
      console.error(`Error ${action}ing ${service}:`, error);
    } finally {
      setLoading((prev) => ({ ...prev, [service]: false }));
    }
  };

  useEffect(() => {
    // Initial load of all service statuses
    serviceList.forEach(fetchServiceStatus);

    // Refresh every 30 seconds
    const interval = setInterval(() => {
      serviceList.forEach(fetchServiceStatus);
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  return (
    <>
      <h2>🔧 Gerenciar Serviços</h2>
      <div className="service-grid">
        {serviceList.map((service) => (
          <div key={service} className="service-row">
            <span style={{ fontWeight: "bold" }}>
              {serviceNames[service as keyof typeof serviceNames]}
            </span>
            <span
              style={{
                color:
                  services[service] === "active"
                    ? "#0f0"
                    : services[service] === "inactive"
                    ? "#f00"
                    : "#ff0",
              }}
            >
              {services[service] === "active"
                ? "Ativo"
                : services[service] === "inactive"
                ? "Parado"
                : "Verificando..."}
            </span>
            <div style={{ display: "flex", gap: "8px" }}>
              <label className="switch">
                <input
                  type="checkbox"
                  checked={services[service] === "active"}
                  onChange={(e) => {
                    if (e.target.checked) {
                      toggleService(service, "start");
                    } else {
                      toggleService(service, "stop");
                    }
                  }}
                  disabled={loading[service]}
                />
                <span className="slider"></span>
              </label>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}
