"use client";

export default function AppButtons() {
  const apps = [
    {
      id: "lndg-btn",
      name: "🔄 LNDg",
      port: 8889,
    },
    {
      id: "thunderhub-btn",
      name: "🌩️ Thunderhub",
      port: 3000,
    },
    {
      id: "lnbits-btn",
      name: "💰 LNBits",
      port: 5000,
    },
    {
      id: "simple-btn",
      name: "📱 Simple LNWallet",
      port: 35671,
    },
  ];

  const openApp = (port: number) => {
    const url = `http://${window.location.hostname}:${port}`;
    window.open(url, "_blank");
  };

  return (
    <div className="botoes">
      {apps.map((app) => (
        <button
          key={app.id}
          id={app.id}
          className="botao"
          onClick={() => openApp(app.port)}
        >
          {app.name}
        </button>
      ))}
    </div>
  );
}
