"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/router";

export default function Login() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    checkSetupStatus();
  }, []);

  const checkSetupStatus = async () => {
    try {
      const response = await fetch("/api/v1/setup/check");
      const data = await response.json();

      if (data.setupComplete) {
        // Diretório /data existe, redireciona para a main page
        router.push("/");
      } else {
        // Diretório /data não existe, redireciona para instalação
        router.push("/install");
      }
    } catch (err) {
      setError("Erro ao verificar status do sistema");
      console.error("Erro:", err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.content}>
        <h1 style={styles.title}>BRLN OS</h1>
        {isLoading && (
          <div style={styles.loadingContainer}>
            <p style={styles.text}>Verificando sistema...</p>
            <div style={styles.spinner}></div>
          </div>
        )}
        {error && (
          <div style={styles.errorContainer}>
            <p style={styles.errorText}>{error}</p>
            <button onClick={checkSetupStatus} style={styles.button}>
              Tentar Novamente
            </button>
          </div>
        )}
      </div>
      <style jsx>{`
        @keyframes spin {
          0% {
            transform: rotate(0deg);
          }
          100% {
            transform: rotate(360deg);
          }
        }
      `}</style>
    </div>
  );
}

const styles = {
  container: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    height: "100vh",
    backgroundColor: "#1a1a1a",
    fontFamily: "system-ui, -apple-system, sans-serif",
  },
  content: {
    textAlign: "center",
  },
  title: {
    fontSize: "48px",
    fontWeight: "bold",
    color: "#fff",
    marginBottom: "40px",
  },
  loadingContainer: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "20px",
  },
  text: {
    fontSize: "18px",
    color: "#ccc",
    margin: 0,
  },
  spinner: {
    width: "40px",
    height: "40px",
    border: "4px solid #333",
    borderTop: "4px solid #ffc107",
    borderRadius: "50%",
    animation: "spin 1s linear infinite",
  },
  errorContainer: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "20px",
  },
  errorText: {
    fontSize: "18px",
    color: "#ff6b6b",
    margin: 0,
  },
  button: {
    padding: "10px 20px",
    fontSize: "16px",
    backgroundColor: "#ffc107",
    color: "#000",
    border: "none",
    borderRadius: "4px",
    cursor: "pointer",
    fontWeight: "bold",
  },
};
