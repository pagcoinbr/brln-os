"use client";

import { useState, useRef, useEffect } from "react";

export default function RadioPlayer() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [volume, setVolume] = useState(0.1);
  const [hasNotifications, setHasNotifications] = useState(false);
  const [isNewsPlaying, setIsNewsPlaying] = useState(false);

  const radioPlayerRef = useRef<HTMLAudioElement>(null);
  const jinglePlayerRef = useRef<HTMLAudioElement>(null);
  const introRef = useRef<HTMLAudioElement>(null);

  useEffect(() => {
    // Check for news notifications every 30 seconds
    const checkNotifications = () => {
      fetch("/api/status_novidade")
        .then((response) => response.json())
        .then((data) => {
          const lastTimestamp = localStorage.getItem("ultimoTimestamp");
          if (data.novidade && data.timestamp !== lastTimestamp) {
            localStorage.setItem("ultimoTimestamp", data.timestamp);
            setHasNotifications(true);
          }
        })
        .catch((err) => {
          console.error("Erro ao consultar status_novidade:", err);
        });
    };

    const interval = setInterval(checkNotifications, 30000);
    return () => clearInterval(interval);
  }, []);

  const toggleRadio = async () => {
    const radioPlayer = radioPlayerRef.current;
    const intro = introRef.current;

    if (!radioPlayer || !intro) return;

    if (radioPlayer.paused) {
      try {
        await intro.play();
        setIsPlaying(true);

        intro.onended = async () => {
          await radioPlayer.play();
        };
      } catch (error) {
        alert(
          "Clique para ativar o som. O navegador pode estar a bloquear o autoplay."
        );
      }
    } else {
      radioPlayer.pause();
      intro.pause();
      intro.currentTime = 0;
      setIsPlaying(false);
    }
  };

  const adjustVolume = (direction: "up" | "down") => {
    const newVolume = volume + (direction === "up" ? 0.1 : -0.1);
    const clampedVolume = Math.max(0, Math.min(1, newVolume));
    setVolume(clampedVolume);

    if (radioPlayerRef.current) {
      radioPlayerRef.current.volume = clampedVolume;
    }
  };

  const playNews = () => {
    if (!isPlaying || isNewsPlaying) return;

    const radioPlayer = radioPlayerRef.current;
    const jinglePlayer = jinglePlayerRef.current;

    if (!radioPlayer || !jinglePlayer) return;

    setIsNewsPlaying(true);
    setHasNotifications(false);

    jinglePlayer.src = "/radio/trecho1.mp3";
    radioPlayer.pause();

    jinglePlayer.play().then(() => {
      console.log("📢 Tocando novidade");
    });

    jinglePlayer.onended = () => {
      setIsNewsPlaying(false);
      radioPlayer.play();
    };
  };

  return (
    <div className="radio-player-container">
      {/* Controls */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          height: "100%",
          paddingLeft: "10px",
        }}
      >
        <button className="radio-button" onClick={toggleRadio}>
          {isPlaying ? "⏸️ Parar" : "▶️ Rádio"}
        </button>

        <button className="vol-control" onClick={() => adjustVolume("down")}>
          −
        </button>

        <button className="vol-control" onClick={() => adjustVolume("up")}>
          +
        </button>

        <button
          className={`novidades-button ${hasNotifications ? "piscando" : ""}`}
          onClick={playNews}
          title={
            hasNotifications
              ? "📣 Novidade disponível! Clique para ouvir"
              : "Sem novidades no momento"
          }
        >
          {hasNotifications ? "🔔" : "📢"}
        </button>
      </div>

      {/* Marquee */}
      <div className="marquee">
        <div className="marquee-content">
          <a
            href="https://services.br-ln.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            ⚡ Clique aqui para acessar o site da BRLN. Junte-se a nós! -
            v1.0-beta
          </a>
        </div>
      </div>

      {/* Hidden Audio Players */}
      <audio
        ref={radioPlayerRef}
        src="https://dc1.serverse.com/proxy/dnutqhxl/stream"
        preload="metadata"
      />
      <audio ref={jinglePlayerRef} preload="metadata" />
      <audio ref={introRef} src="/radio/intro.mp3" preload="metadata" />
    </div>
  );
}
