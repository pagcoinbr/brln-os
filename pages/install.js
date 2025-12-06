"use client";

import { useState } from "react";
import { useRouter } from "next/router";

export default function Install() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);

  const handleInstall = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch("/api/v1/setup/init", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      const data = await response.json();

      if (data.success) {
        setSuccess(true);
        // Redireciona para a main page após 2 segundos
        setTimeout(() => {
          router.push("/");
        }, 2000);
      } else {
        setError(data.error || "Erro ao inicializar o sistema");
      }
    } catch (err) {
      setError("Erro na requisição: " + err.message);
      console.error("Erro:", err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.content}>
        <h1 style={styles.title}>BRLN OS - Instalação</h1>

        {!success && (
          <div style={styles.installContainer}>
            <p style={styles.description}>
              Bem-vindo ao BRLN OS! É necessário inicializar o sistema antes de
              começar.
            </p>

            {error && (
              <div style={styles.errorBox}>
                <p style={styles.errorText}>⚠️ {error}</p>
              </div>
            )}

            <button
              onClick={handleInstall}
              disabled={isLoading}
              style={{
                ...styles.installButton,
                opacity: isLoading ? 0.6 : 1,
                cursor: isLoading ? "not-allowed" : "pointer",
              }}
            >
              {isLoading ? "Inicializando..." : "Inicializar Sistema"}
            </button>
          </div>
        )}

        {success && (
          <div style={styles.successContainer}>
            <p style={styles.successText}>
              ✓ Sistema inicializado com sucesso!
            </p>
            <p style={styles.redirectText}>Redirecionando...</p>
          </div>
        )}
      </div>
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
    maxWidth: "500px",
  },
  title: {
    fontSize: "36px",
    fontWeight: "bold",
    color: "#fff",
    marginBottom: "40px",
  },
  installContainer: {
    display: "flex",
    flexDirection: "column",
    gap: "20px",
  },
  description: {
    fontSize: "16px",
    color: "#ccc",
    lineHeight: "1.5",
    marginBottom: "20px",
  },
  errorBox: {
    backgroundColor: "#2a1a1a",
    border: "1px solid #ff6b6b",
    borderRadius: "4px",
    padding: "15px",
  },
  errorText: {
    color: "#ff6b6b",
    margin: 0,
    fontSize: "14px",
  },
  installButton: {
    padding: "12px 30px",
    fontSize: "16px",
    fontWeight: "bold",
    backgroundColor: "#ffc107",
    color: "#000",
    border: "none",
    borderRadius: "4px",
    cursor: "pointer",
    transition: "background-color 0.3s",
  },
  successContainer: {
    display: "flex",
    flexDirection: "column",
    gap: "15px",
  },
  successText: {
    fontSize: "20px",
    color: "#4caf50",
    margin: 0,
    fontWeight: "bold",
  },
  redirectText: {
    fontSize: "14px",
    color: "#999",
    margin: 0,
  },
};
