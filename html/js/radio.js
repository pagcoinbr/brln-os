const player = document.getElementById('radio-player');
const button = document.getElementById('radio-button');
const volUp = document.getElementById('vol-up');
const volDown = document.getElementById('vol-down');

player.volume = 0.1;

const jinglePlayer = new Audio();
jinglePlayer.volume = 0.8;

const intro = new Audio("radio/intro.mp3");

const trechos = [
  "radio/trecho1.mp3",
  "radio/trecho2.mp3",
  "radio/trecho3.mp3"
];

let novidadesAtivas = false;
let intervaloTrechos = null;

function toggleRadio() {
  if (player.paused) {
    intro.play().then(() => {
      console.log("Intro iniciada");
      button.innerText = "⏸️ Parar";
    }).catch(() => {
      alert("Clique para ativar o som. O navegador pode estar a bloquear o autoplay.");
    });

    intro.addEventListener("ended", () => {
      player.play().then(() => {
        console.log("Rádio iniciada");
      });
    });

  } else {
    player.pause();
    intro.pause();
    intro.currentTime = 0;
    button.innerText = "▶️ Rádio";
  }
}

function ajustarVolume(direcao) {
  let novoVolume = player.volume + (direcao === 'up' ? 0.1 : -0.1);
  novoVolume = Math.max(0, Math.min(1, novoVolume));
  player.volume = novoVolume;
  console.log("Volume atual:", Math.round(novoVolume * 100) + "%");
}

function tocarInterrupcao() {
  if (!player.paused) {
    const indice = Math.floor(Math.random() * trechos.length);
    const trechoSelecionado = trechos[indice];
    jinglePlayer.src = trechoSelecionado;
    player.pause();
    jinglePlayer.play().then(() => {
      console.log("Tocando novidade:", trechoSelecionado);
    });
  }
}

jinglePlayer.addEventListener("ended", () => {
  player.play().then(() => {
    console.log("Rádio retomada");
  });
});

button.addEventListener('click', toggleRadio);
volUp.addEventListener('click', () => ajustarVolume('up'));
volDown.addEventListener('click', () => ajustarVolume('down'));

// NOVO BOTÃO DE NOVIDADES (Agora com o ícone 📢)
const botaoNovidades = document.createElement("button");
botaoNovidades.textContent = "📢";
botaoNovidades.className = "vol-control";
botaoNovidades.title = "Ativar/Desativar Novidades";
button.parentNode.appendChild(botaoNovidades);

botaoNovidades.addEventListener("click", () => {
  novidadesAtivas = !novidadesAtivas;

  if (novidadesAtivas) {
    // Toca o primeiro trecho imediatamente
    tocarInterrupcao();

    // Inicia o intervalo para os próximos trechos após 5 minutos
    intervaloTrechos = setInterval(tocarInterrupcao, 60000); // 1 minuto
    botaoNovidades.style.backgroundColor = "#006666"; // Ativo
    console.log("Novidades ativadas");
  } else {
    clearInterval(intervaloTrechos);
    botaoNovidades.style.backgroundColor = ""; // Reset
    console.log("Novidades desativadas");
  }
});