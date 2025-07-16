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

  // Atualiza a cada 5 segundos quando 5000ms
  setInterval(atualizarStatus, 50000);
  window.onload = atualizarStatus;

// Base URL do Flask
const flaskBaseURL = `http://${window.location.hostname}:5001`;

// Lista dos apps que aparecem no menu principal
const appsPrincipais = [
  { id: 'lndg-btn', porta: 8889 },
  { id: 'thunderhub-btn', porta: 3000 },
  { id: 'lnbits-btn', porta: 5000 },
  { id: 'peerswap-btn', porta: 1984 },
];

// Lista dos apps gerenciados no painel de serviços
const appsServicos = ["lnbits", "thunderhub", "lndg", "lnd", "bitcoind", "bos-telegram", "tor"];

document.addEventListener('DOMContentLoaded', () => {
  // Aplica o tema salvo
  const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
  document.body.classList.add(`${temaSalvo}-theme`);

  // Atualiza status dos botões
  updateButtons();

  // Atualiza saldos das carteiras
  updateWalletBalances();

  // Verifica o status dos apps principais (de navegação)
  setTimeout(verificarServicosPrincipais, 50000);

  // Atualiza status dos botões de serviços a cada 5 segundos
  setInterval(updateButtons, 50000);

  // Atualiza saldos das carteiras a cada 5 minutos (300000ms)
  setInterval(updateWalletBalances, 300000);
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
    { id: 'simple-btn', porta: 1984 },
  ];

  const ip = window.location.hostname;
  const timeout = 51000;

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
          setTimeout(checkService, 51000);
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

// Formata o nome dos apps
function formatAppName(appName) {
  switch (appName) {
    case "lnbits": return "LNbits";
    case "thunderhub": return "Thunderhub";
    case "simple": return "Simple LNWallet";
    case "lndg": return "LNDG";
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

// Função para atualizar saldos das carteiras
async function updateWalletBalances() {
  const lightningElement = document.getElementById('lightning-balance');
  const bitcoinElement = document.getElementById('bitcoin-balance');
  const liquidElement = document.getElementById('liquid-balance');
  const statusElement = document.getElementById('wallet-status');

  // Definir status de carregamento
  lightningElement.textContent = '⚡ Lightning: 🔄 Verificando...';
  bitcoinElement.textContent = '₿ Bitcoin On-Chain: 🔄 Verificando...';
  liquidElement.textContent = '🌊 Liquid/Elements: 🔄 Verificando...';
  statusElement.textContent = '🔄 Atualizando saldos...';

  try {
    const response = await fetch(`${flaskBaseURL}/wallet-balances`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    
    if (data.success) {
      // Parse da saída do cliente Python
      const output = data.raw_output || '';
      const timestamp = data.timestamp || new Date().toLocaleString('pt-BR');
      
      // Extrair saldos da saída usando regex
      const lightningBalance = extractLightningBalance(output);
      const bitcoinBalance = extractBitcoinBalance(output);
      const liquidBalance = extractLiquidBalance(output);
      
      // Atualizar elementos DOM
      lightningElement.textContent = `⚡ Lightning: ${lightningBalance}`;
      bitcoinElement.textContent = `₿ Bitcoin On-Chain: ${bitcoinBalance}`;
      liquidElement.textContent = `🌊 Liquid/Elements: ${liquidBalance}`;
      
      // Status das conexões
      const lndStatus = data.connections?.lnd ? '✅' : '❌';
      const elementsStatus = data.connections?.elements ? '✅' : '❌';
      statusElement.textContent = `🔄 Última atualização: ${timestamp} | LND: ${lndStatus} | Elements: ${elementsStatus}`;
      
    } else {
      throw new Error(data.error || 'Erro desconhecido');
    }

  } catch (error) {
    console.error('Erro ao obter saldos:', error);
    
    lightningElement.textContent = '⚡ Lightning: ❌ Erro';
    bitcoinElement.textContent = '₿ Bitcoin On-Chain: ❌ Erro';
    liquidElement.textContent = '🌊 Liquid/Elements: ❌ Erro';
    statusElement.textContent = `❌ Erro: ${error.message}`;
  }
}

// Função para extrair saldo Lightning da saída
function extractLightningBalance(output) {
  try {
    // Procura por "Saldo Local:" seguido do valor
    const localMatch = output.match(/Saldo Local:\s*([0-9.,]+\s*BTC[^)]*\([^)]+\))/);
    if (localMatch) {
      return localMatch[1].trim();
    }
    
    // Fallback: procura por qualquer padrão de BTC
    const btcMatch = output.match(/([0-9.]+\s*BTC[^)]*\([^)]+\))/);
    if (btcMatch) {
      return btcMatch[1].trim();
    }
    
    return 'Não disponível';
  } catch (e) {
    return 'Erro na leitura';
  }
}

// Função para extrair saldo Bitcoin on-chain da saída
function extractBitcoinBalance(output) {
  try {
    // Procura por "Total:" na seção Bitcoin on-chain
    const totalMatch = output.match(/Total:\s*([0-9.,]+\s*BTC[^)]*\([^)]+\))/);
    if (totalMatch) {
      return totalMatch[1].trim();
    }
    
    // Fallback: procura por "Confirmado:"
    const confirmedMatch = output.match(/Confirmado:\s*([0-9.,]+\s*BTC[^)]*\([^)]+\))/);
    if (confirmedMatch) {
      return confirmedMatch[1].trim();
    }
    
    return 'Não disponível';
  } catch (e) {
    return 'Erro na leitura';
  }
}

// Função para extrair saldo Liquid/Elements da saída
function extractLiquidBalance(output) {
  try {
    // Procura por valores L-BTC ou outros assets
    const liquidMatch = output.match(/Confirmado:\s*([^\\n]+L-BTC[^\\n]*)/);
    if (liquidMatch) {
      return liquidMatch[1].trim();
    }
    
    // Fallback: procura na seção Elements
    const elementsSection = output.match(/LIQUID \(ELEMENTS\)(.*?)(?=\n\n|Status das Conexões|$)/s);
    if (elementsSection) {
      const balanceMatch = elementsSection[1].match(/Confirmado:\s*([^\\n]+)/);
      if (balanceMatch) {
        return balanceMatch[1].trim();
      }
    }
    
    return 'Não disponível';
  } catch (e) {
    return 'Erro na leitura';
  }
}

// Função para formatar valores para exibição mais compacta
function formatBalanceForDisplay(balanceText) {
  if (!balanceText || balanceText === 'Não disponível') {
    return balanceText;
  }
  
  try {
    // Remove texto extra e mantém apenas o essencial
    return balanceText.replace(/\s+/g, ' ').trim();
  } catch (e) {
    return balanceText;
  }
}