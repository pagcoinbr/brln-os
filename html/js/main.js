function atualizarStatus() {
  fetch('/cgi-bin/status.sh')
      .then(res => {
          if (!res.ok) {
              throw new Error('Erro ao obter status do sistema.');
          }
          return res.text(); // ✅ <- Aqui trocamos para texto simples
      })
      .then(text => {
          const lines = text.split('\n');
          for (const line of lines) {
              if (line.includes("CPU:")) {
                  document.getElementById("cpu").innerText = line;
              } else if (line.includes("RAM:")) {
                  document.getElementById("ram").innerText = line;
              } else if (line.includes("LND:")) {
                  document.getElementById("lnd").innerText = line;
              } else if (line.includes("Bitcoind:")) {
                  document.getElementById("bitcoind").innerText = line;              
              } else if (line.includes("Elements:")) {
                  document.getElementById("elements").innerText = line;
              } else if (line.includes("Tor:")) {
                  document.getElementById("tor").innerText = line;
              } else if (line.includes("Blockchain:")) {
                  document.getElementById("blockchain").innerText = line;
              }
          }
      })
      .catch(error => {
          alert("Erro ao atualizar status: " + error.message);
      });
}

  // Atualiza a cada 5 segundos
  setInterval(atualizarStatus, 5000);
  window.onload = atualizarStatus;

// Base URL do Flask
const flaskBaseURL = `http://${window.location.hostname}:5001`;

// Lista dos apps que aparecem no menu principal
const appsPrincipais = [
  { id: 'lndg-btn', porta: 8889 },
  { id: 'thunderhub-btn', porta: 3000 },
  { id: 'lnbits-btn', porta: 5000 },
  { id: 'simple-btn', porta: 35671 },
];

// Lista dos apps gerenciados no painel de serviços
const appsServicos = ["lnbits", "thunderhub", "simple", "lndg", "lndg-controller", "lnd", "bitcoind", "elementsd", "bos-telegram", "tor"];

document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Atualiza status dos botões
  updateButtons();

  // Verifica o status dos apps principais (de navegação)
  setTimeout(verificarServicosPrincipais, 1000);

  // Atualiza status dos botões de serviços a cada 5 segundos
  setInterval(updateButtons, 5000);
});

// Função para abrir apps principais
function abrirApp(porta) {
  const ip = window.location.hostname;
  window.open(`http://${ip}:${porta}`, '_blank');
}

function verificarServicosPrincipais() {
  const apps = [
    { id: 'lndg-btn', porta: 8889 },
    { id: 'thunderhub-btn', porta: 3000 },
    { id: 'lnbits-btn', porta: 5000 },
    { id: 'simple-btn', porta: 35671 },
  ];

  const ip = window.location.hostname;
  const timeout = 2000;

  apps.forEach(app => {
    const botao = document.getElementById(app.id);
    if (botao) {
      botao.disabled = true;
      botao.style.opacity = "0.5";
      botao.style.cursor = "not-allowed";
      botao.title = "Seviço Desativado.";
    }

    const url = `http://${ip}:${app.porta}`;

    const checkService = () => {
      const fetchWithTimeout = new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject('Timeout'), timeout);
        fetch(url, { method: 'HEAD', mode: 'no-cors' })
          .then(response => {
            clearTimeout(timer);
            resolve(response);
          })
          .catch(reject);
      });

      fetchWithTimeout
        .then(() => {
          const botao = document.getElementById(app.id);
          if (botao) {
            botao.disabled = false;
            botao.style.opacity = "1";
            botao.style.cursor = "pointer";
            botao.title = "Serviço disponível";
          }
        })
        .catch(() => {
          setTimeout(checkService, 2000);
        });
    };

    checkService();
  });
}

// Atualiza status dos botões de serviços
async function updateButtons() {
  for (const appName of appsServicos) {
    const button = document.getElementById(`${appName}-button`);
    if (!button) continue;
    try {
      const response = await fetch(`${flaskBaseURL}/service-status?app=${appName}`);
      const data = await response.json();

      button.checked = data.active; // marca ou desmarca o switch
      button.dataset.action = data.active ? "stop" : "start";

    } catch (error) {
      console.error(`Erro ao verificar status de ${appName}:`, error);
    }
  }
}

async function toggleService(appName) {
  try {
    const response = await fetch(`${flaskBaseURL}/toggle-service?app=${appName}`, {
      method: 'POST'
    });
    const data = await response.json();
    if (data.success) {
      await updateButtons();
    } else {
      alert('Erro: ' + (data.error || 'Ação falhou'));
    }
  } catch (error) {
    console.error(error);
    alert('Erro ao enviar ação');
  }
}

// Formata o nome dos apps bonitinho
function formatAppName(appName) {
  switch (appName) {
    case "lnbits": return "LNbits";
    case "thunderhub": return "Thunderhub";
    case "simple": return "Simple LNWallet";
    case "lndg": return "LNDG";
    case "lndg-controller": return "LNDG Controller";
    case "lnd": return "LND";
    default: return appName;
  }
}

// Alternar tema claro/escuro
function alternarTema() {
  const body = document.body;
  const temaAtual = body.classList.contains('dark-theme') ? 'dark' : 'light';
  const novoTema = temaAtual === 'dark' ? 'light' : 'dark';

  body.classList.remove(`${temaAtual}-theme`);
  body.classList.add(`${novoTema}-theme`);

  localStorage.setItem('temaAtual', novoTema);
}

// Salvar última página aberta (opcional)
function salvarPagina(pagina) {
  localStorage.setItem('ultimaPaginaMainFrame', pagina);
}

function toggleExtras(button) {
  const extras = document.getElementById("extras");
  const isHidden = extras.style.display === "none";
  extras.style.display = isHidden ? "block" : "none";
  button.classList.toggle("rotate", isHidden);
}