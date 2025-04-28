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

function abrirApp(porta) {
  const ip = window.location.hostname;
  const width = 900;
  const height = 600;
  const left = (screen.width - width) / 2;
  const top = (screen.height - height) / 2;

  window.open(`http://${ip}:${porta}`, '_blank',
      `width=${width},height=${height},left=${left},top=${top},resizable=yes`);
}

function alternarTema() {
    const body = document.body;
    const temaAtual = body.classList.contains('dark-theme') ? 'dark' : 'light';
    const novoTema = temaAtual === 'dark' ? 'light' : 'dark';
  
    body.classList.remove(`${temaAtual}-theme`);
    body.classList.add(`${novoTema}-theme`);
  
    localStorage.setItem('temaAtual', novoTema);
  
    // Recarrega o mainFrame também
    const mainFrame = parent.document.getElementById('mainFrame');
    if (mainFrame) {
      mainFrame.contentWindow.location.reload();
    }
}  
  

// Base URL do Flask
const flaskBaseURL = `http://${window.location.hostname}:5001`;

// Lista dos apps que vamos gerenciar
const apps = ["lnbits", "thunderhub", "simple", "lndg", "lndg-controller", "lnd"];
const buttonsContainer = document.getElementById('buttons-container');

// Cria um botão para cada app
apps.forEach(appName => {
const button = document.createElement('button');
button.id = `${appName}-button`;
button.textContent = `Carregando ${formatAppName(appName)}...`;
button.dataset.app = appName;
button.style.margin = '10px';
button.addEventListener('click', () => toggleService(appName));
buttonsContainer.appendChild(button);
});

// Atualiza o status dos botões
async function updateButtons() {
for (const appName of apps) {
const button = document.getElementById(`${appName}-button`);
try {
const response = await fetch(`${flaskBaseURL}/service-status?app=${appName}`);
const data = await response.json();
if (data.active) {
  button.textContent = `Parar ${formatAppName(appName)}`;
  button.dataset.action = "stop";
} else {
  button.textContent = `Iniciar ${formatAppName(appName)}`;
  button.dataset.action = "start";
}
} catch (error) {
button.textContent = `Erro ao carregar ${formatAppName(appName)}`;
console.error(error);
}
}
}

// Função para start/stop do serviço
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

// Função para melhorar os nomes exibidos
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

document.addEventListener('DOMContentLoaded', () => {
    const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
    document.body.classList.add(`${temaSalvo}-theme`);
    
    atualizarStatus();    // Atualiza o painel na hora que abrir
    updateButtons();      // Atualiza o gerenciador de serviços na hora que abrir
});

  // Atualiza a cada 5 segundos
  setInterval(() => {
    atualizarStatus();
    updateButtons();
  }, 5000);
  