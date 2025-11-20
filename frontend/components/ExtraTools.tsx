"use client";

import { useState } from "react";

interface ExtraToolsProps {
  onThemeToggle: () => void;
}

export default function ExtraTools({ onThemeToggle }: ExtraToolsProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  const externalLinks = [
    { name: "🌐 AMBOSS", url: "https://amboss.space" },
    { name: "➕ Lightning Network +", url: "https://lightningnetwork.plus/" },
    { name: "🧱 Mempool", url: "https://mempool.space" },
    { name: "🤖 RoboSats DEX", url: "https://unsafe.robosats.org/" },
    {
      name: "🔗 On-chain Fee Calculator",
      url: "https://tools.bitbo.io/fee-calculator/",
    },
    {
      name: "📊 Bitcoin Dashboard",
      url: "https://bitcoin.clarkmoody.com/dashboard/",
    },
    {
      name: "📈 Lightning Dashboard",
      url: "https://bitcoinvisuals.com/lightning",
    },
  ];

  return (
    <div className="container">
      <div className="section">
        <h3>🛠️ Ferramentas Extras</h3>
        <button
          className="toggle-btn"
          onClick={() => setIsExpanded(!isExpanded)}
          style={{ display: "inline", margin: "0px" }}
        >
          {isExpanded ? "🔼" : "🔽"}
        </button>

        {isExpanded && (
          <div
            className="ferramentas-extras"
            style={{ display: isExpanded ? "grid" : "none", marginTop: "10px" }}
          >
            {externalLinks.map((link) => (
              <a
                key={link.name}
                href={link.url}
                target="_blank"
                rel="noopener noreferrer"
                className="botao"
              >
                {link.name}
              </a>
            ))}

            <button onClick={onThemeToggle} className="botao">
              🌗 Alterar Tema
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
