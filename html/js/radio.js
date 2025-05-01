const player = document.getElementById('radio-player');
const button = document.getElementById('radio-button');
const volUp = document.getElementById('vol-up');
const volDown = document.getElementById('vol-down');
const botaoNovidades = document.getElementById("novidades-button");

let ultimoTimestamp = null;
let novidadesAtivas = false;

player.volume = 0.1;

const jinglePlayer = new Audio();
jinglePlayer.volume = 0.8;

const intro = new Audio("radio/intro.mp3");

const trechos = [
  "radio/trecho1.mp3"
];

// Função para tocar trecho de novidade
function tocarInterrupcao() {
  if (!player.paused && !novidadesAtivas) {
    const indice = Math.floor(Math.random() * trechos.length);
    const trechoSelecionado = trechos[indice];
    jinglePlayer.src = trechoSelecionado;
    novidadesAtivas = true;
    player.pause();
    jinglePlayer.play().then(() => {
      console.log("📢 Tocando novidade:", trechoSelecionado);
    });
  }
}

// Quando a novidade terminar, volta à rádio
jinglePlayer.addEventListener("ended", () => {
  novidadesAtivas = false;
  botaoNovidades.innerText = "📢"; // volta ao ícone original
  botaoNovidades.title = "Sem novidades no momento";
  player.play().then(() => {
    console.log("▶️ Rádio retomada");
  });
});

// Verifica o arquivo de flag e pisca o botão de novidades se necessário
setInterval(() => {
  fetch('/html/radio/update_available.flag?ts=' + Date.now())
    .then(response => response.text())
    .then(timestamp => {
      timestamp = timestamp.trim();
      if (timestamp && timestamp !== ultimoTimestamp) {
        ultimoTimestamp = timestamp;
        botaoNovidades.classList.add("piscando");
        botaoNovidades.innerText = "🔔";
        botaoNovidades.title = "📣 Novidade disponível! Clique para ouvir";
        console.log("🔔 Novidade detectada!");
      }         
    })
    .catch(err => {
      console.error("Erro ao verificar atualizações da rádio:", err);
    });
}, 60000);

// Lógica do botão de rádio
function toggleRadio() {
  if (player.paused) {
    intro.play().then(() => {
      console.log("▶️ Intro iniciada");
      button.innerText = "⏸️ Parar";
    }).catch(() => {
      alert("Clique para ativar o som. O navegador pode estar a bloquear o autoplay.");
    });

    intro.addEventListener("ended", () => {
      player.play().then(() => {
        console.log("▶️ Rádio iniciada");
      });
    });

  } else {
    player.pause();
    intro.pause();
    intro.currentTime = 0;
    button.innerText = "▶️ Rádio";
  }
}

// Ajuste de volume
function ajustarVolume(direcao) {
  let novoVolume = player.volume + (direcao === 'up' ? 0.1 : -0.1);
  player.volume = Math.max(0, Math.min(1, novoVolume));
  console.log("🔊 Volume:", Math.round(player.volume * 100) + "%");
}

// Eventos
button.addEventListener('click', toggleRadio);
volUp.addEventListener('click', () => ajustarVolume('up'));
volDown.addEventListener('click', () => ajustarVolume('down'));
botaoNovidades.addEventListener('click', tocarInterrupcao);
