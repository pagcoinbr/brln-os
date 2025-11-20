"use client";

import { useEffect, useState } from "react";
import RadioPlayer from "@/components/RadioPlayer";
import SystemStatus from "@/components/SystemStatus";
import AppButtons from "@/components/AppButtons";
import ExtraTools from "@/components/ExtraTools";
import ServiceManagement from "@/components/ServiceManagement";
import Image from "next/image";

export default function HomePage() {
  const [theme, setTheme] = useState<"light" | "dark">("dark");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    const savedTheme = localStorage.getItem("theme") as "light" | "dark" | null;
    const preferredTheme = savedTheme || "dark";
    setTheme(preferredTheme);
    document.body.className =
      preferredTheme === "dark" ? "dark-theme" : "light-theme";
  }, []);

  const toggleTheme = () => {
    const newTheme = theme === "dark" ? "light" : "dark";
    setTheme(newTheme);
    document.body.className =
      newTheme === "dark" ? "dark-theme" : "light-theme";
    localStorage.setItem("theme", newTheme);
  };

  if (!mounted) {
    return (
      <div className="loading-container">
        <div className="loading-content">
          <div className="logo-container">
            <Image
              src="/images/BRLNlogo.png"
              alt="BRLN Open Bank"
              width={200}
              height={100}
              className="loading-logo"
              priority
            />
          </div>

          <div className="spinner-container">
            <div className="spinner">
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
              <div className="lightning-bolt">⚡</div>
            </div>
          </div>

          <div className="loading-text">
            <span className="typing-text">Carregando BRLN Open Bank</span>
            <span className="dots">
              <span>.</span>
              <span>.</span>
              <span>.</span>
            </span>
          </div>

          <div className="loading-subtitle">
            Conectando ao Lightning Network...
          </div>
        </div>

        <style jsx>{`
          .loading-container {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(
              135deg,
              #000428 0%,
              #004e92 50%,
              #000428 100%
            );
            background-size: 400% 400%;
            animation: gradientShift 6s ease infinite;
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            overflow: hidden;
            position: relative;
          }

          .loading-container::before {
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(
                circle at 30% 50%,
                rgba(255, 193, 7, 0.1) 0%,
                transparent 50%
              ),
              radial-gradient(
                circle at 70% 50%,
                rgba(0, 123, 255, 0.1) 0%,
                transparent 50%
              );
            animation: floatingOrbs 8s ease-in-out infinite;
          }

          .loading-content {
            text-align: center;
            z-index: 10;
            position: relative;
          }

          .logo-container {
            margin-bottom: 2rem;
            animation: logoGlow 2s ease-in-out infinite alternate;
          }

          .loading-logo {
            filter: drop-shadow(0 0 20px rgba(255, 193, 7, 0.5));
            animation: logoFloat 3s ease-in-out infinite;
          }

          .spinner-container {
            margin: 2rem 0;
            display: flex;
            justify-content: center;
            align-items: center;
          }

          .spinner {
            position: relative;
            width: 80px;
            height: 80px;
            display: flex;
            align-items: center;
            justify-content: center;
          }

          .spinner-ring {
            position: absolute;
            border: 3px solid transparent;
            border-radius: 50%;
            animation: spin 2s linear infinite;
          }

          .spinner-ring:nth-child(1) {
            width: 80px;
            height: 80px;
            border-top-color: #ffc107;
            animation-duration: 2s;
          }

          .spinner-ring:nth-child(2) {
            width: 60px;
            height: 60px;
            border-right-color: #007bff;
            animation-duration: 1.5s;
            animation-direction: reverse;
          }

          .spinner-ring:nth-child(3) {
            width: 40px;
            height: 40px;
            border-bottom-color: #28a745;
            animation-duration: 1s;
          }

          .lightning-bolt {
            font-size: 1.5rem;
            color: #ffc107;
            animation: pulse 1s ease-in-out infinite;
            z-index: 10;
          }

          .loading-text {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
          }

          .typing-text {
            background: linear-gradient(45deg, #ffc107, #007bff, #28a745);
            background-size: 200% 200%;
            background-clip: text;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: gradientText 3s ease infinite;
          }

          .dots {
            display: flex;
            gap: 0.2rem;
          }

          .dots span {
            animation: dotBounce 1.5s infinite;
            color: #ffc107;
          }

          .dots span:nth-child(2) {
            animation-delay: 0.2s;
          }

          .dots span:nth-child(3) {
            animation-delay: 0.4s;
          }

          .loading-subtitle {
            font-size: 1rem;
            opacity: 0.8;
            color: #ccc;
            animation: fadeInOut 2s ease-in-out infinite;
          }

          @keyframes gradientShift {
            0%,
            100% {
              background-position: 0% 50%;
            }
            50% {
              background-position: 100% 50%;
            }
          }

          @keyframes floatingOrbs {
            0%,
            100% {
              transform: translateY(0px);
            }
            50% {
              transform: translateY(-20px);
            }
          }

          @keyframes logoGlow {
            0% {
              filter: drop-shadow(0 0 20px rgba(255, 193, 7, 0.5));
            }
            100% {
              filter: drop-shadow(0 0 30px rgba(255, 193, 7, 0.8));
            }
          }

          @keyframes logoFloat {
            0%,
            100% {
              transform: translateY(0px);
            }
            50% {
              transform: translateY(-10px);
            }
          }

          @keyframes spin {
            from {
              transform: rotate(0deg);
            }
            to {
              transform: rotate(360deg);
            }
          }

          @keyframes pulse {
            0%,
            100% {
              transform: scale(1);
              opacity: 1;
            }
            50% {
              transform: scale(1.2);
              opacity: 0.8;
            }
          }

          @keyframes gradientText {
            0%,
            100% {
              background-position: 0% 50%;
            }
            50% {
              background-position: 100% 50%;
            }
          }

          @keyframes dotBounce {
            0%,
            60%,
            100% {
              transform: translateY(0);
            }
            30% {
              transform: translateY(-10px);
            }
          }

          @keyframes fadeInOut {
            0%,
            100% {
              opacity: 0.6;
            }
            50% {
              opacity: 1;
            }
          }
        `}</style>
      </div>
    );
  }

  return (
    <>
      {/* Radio Player at top */}
      <div style={{ position: "fixed", top: 0, left: 0, right: 0, zIndex: 50 }}>
        <RadioPlayer />
      </div>

      {/* Main content */}
      <div style={{ paddingTop: "60px" }}>
        {/* Logo */}
        <Image
          src="/images/BRLNlogo.png"
          alt="BRLN Open Bank logo"
          width={800}
          height={400}
          className="brln-logo"
          priority
        />

        {/* Main App Buttons */}
        <AppButtons />

        {/* Extra Tools */}
        <ExtraTools onThemeToggle={toggleTheme} />

        {/* Configuration Panel */}
        <div className="container">
          <div className="section">
            <h1>⚙️ Painel de Configurações</h1>

            {/* System Status */}
            <SystemStatus />

            {/* Service Management */}
            <ServiceManagement />
          </div>
        </div>
      </div>
    </>
  );
}
