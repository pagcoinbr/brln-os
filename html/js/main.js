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
const appsServicos = ["lnbits", "thunderhub", "simple", "lndg", "lndg-controller", "lnd"];

document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Cria botões do painel de serviços
  const buttonsContainer = document.getElementById('buttons-container');
  appsServicos.forEach(appName => {
    const button = document.createElement('button');
    button.id = `${appName}-button`;
    button.textContent = `Carregando ${formatAppName(appName)}...`;
    button.dataset.app = appName;
    button.classList.add('botao'); // Adiciona a classe correta
    button.style.margin = '10px';
    button.addEventListener('click', () => toggleService(appName));
    buttonsContainer.appendChild(button);
  });

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

// Verifica os serviços principais e habilita/desabilita botões do menu
function verificarServicosPrincipais() {
  const ip = window.location.hostname;

  appsPrincipais.forEach(app => {
    const botao = document.getElementById(app.id);
    if (botao) {
      botao.disabled = true;
      botao.style.opacity = "0.5";
      botao.style.cursor = "not-allowed";
    }

    const url = `http://${ip}:${app.porta}`;
    const checkService = () => {
      fetch(url, { method: 'HEAD', mode: 'no-cors' })
        .then(() => {
          if (botao) {
            botao.disabled = false;
            botao.style.opacity = "1";
            botao.style.cursor = "pointer";
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
      if (data.active) {
        button.textContent = `⏹️ Parar ${formatAppName(appName)}`;
        button.dataset.action = "stop";
      } else {
        button.textContent = `▶️ Iniciar ${formatAppName(appName)}`;
        button.dataset.action = "start";
      }
    } catch (error) {
      button.textContent = `❌ Erro: ${formatAppName(appName)}`;
      console.error(error);
    }
  }
}

// Envia comando para iniciar/parar serviço
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
