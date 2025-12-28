// Sistema de gerenciamento de config BRLN-OS

// Abrir aplicativo em nova janela
function abrirApp(porta) {
  const url = `http://${window.location.hostname}:${porta}`;
  window.open(url, '_blank');
}

// Função para abrir modal do terminal
function openTerminalModal() {
  const modal = document.getElementById('terminalModal');
  const iframe = document.getElementById('terminalIframe');
  const url = '/terminal/';
  
  // Definir a URL do iframe
  iframe.src = url;
  
  // Mostrar o modal
  modal.style.display = 'block';
  
  // Prevenir scroll do body
  document.body.style.overflow = 'hidden';
}

// Função para fechar modal do terminal
function closeTerminalModal() {
  const modal = document.getElementById('terminalModal');
  const iframe = document.getElementById('terminalIframe');
  
  // Esconder o modal
  modal.style.display = 'none';
  
  // Limpar o iframe
  iframe.src = '';
  
  // Restaurar scroll do body
  document.body.style.overflow = 'auto';
}

// Make functions globally accessible
window.openTerminalModal = openTerminalModal;
window.closeTerminalModal = closeTerminalModal;

// Fechar modal ao clicar fora dele
window.onclick = function(event) {
  const modal = document.getElementById('terminalModal');
  if (event.target == modal) {
    closeTerminalModal();
  }
}

// Fechar modal com tecla ESC
document.addEventListener('keydown', function(event) {
  if (event.key === 'Escape') {
    const modal = document.getElementById('terminalModal');
    if (modal.style.display === 'block') {
      closeTerminalModal();
    }
  }
});

// Toggle de serviços
async function toggleService(serviceName) {
  const checkbox = document.getElementById(`${serviceName}-button`);
  
  try {
    console.log(`Toggling service: ${serviceName}`);
    const response = await fetch('/api/v1/system/service', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin',
      body: JSON.stringify({
        service: serviceName
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    if (!response.ok) {
      console.error('Erro ao gerenciar serviço:', data.error);
      // Reverter o checkbox em caso de erro
      checkbox.checked = !checkbox.checked;
      alert(`Erro ao gerenciar ${serviceName}: ${data.error}`);
    } else {
      // Atualizar checkbox com o novo status retornado pela API
      checkbox.checked = data.current_status;
      console.log(`Serviço ${serviceName}: ${data.message}`);
    }
  } catch (error) {
    console.error('Erro na requisição:', error);
    // Reverter o checkbox em caso de erro
    checkbox.checked = !checkbox.checked;
    alert(`Erro ao comunicar com o servidor: ${error.message}`);
  }
}

// Carregar status dos serviços
async function loadServicesStatus() {
  console.log('Carregando status dos serviços...');
  try {
    console.log('Fazendo fetch para: https://brln-os.pagcoin.org/api/v1/system/services');
    const response = await fetch('https://brln-os.pagcoin.org/api/v1/system/services', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    });
    console.log('Resposta da API services:', response.status);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data = await response.json();
    console.log('Dados dos serviços:', data);
    
    if (data.services) {
      Object.keys(data.services).forEach(service => {
        const checkbox = document.getElementById(`${service}-button`);
        if (checkbox) {
          console.log(`Atualizando ${service}: ${data.services[service]}`);
          checkbox.checked = data.services[service];
        } else {
          console.warn(`Checkbox não encontrado para o serviço: ${service}`);
        }
      });
    }
  } catch (error) {
    console.error('Erro ao carregar status dos serviços:', error);
  }
}

// Carregar status do sistema
async function loadSystemStatus() {
  try {
    console.log('Fazendo fetch para: https://brln-os.pagcoin.org/api/v1/system/status');
    const response = await fetch('https://brln-os.pagcoin.org/api/v1/system/status', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    });
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data = await response.json();
    
    // Atualizar CPU
    const cpuElement = document.getElementById('cpu');
    if (data.cpu) {
      cpuElement.textContent = `CPU: ${data.cpu.usage}% | Load: ${data.cpu.load}`;
      cpuElement.style.background = data.cpu.usage > 80 ? '#ff4444' : '#90EE90';
    }
    
    // Atualizar RAM
    const ramElement = document.getElementById('ram');
    if (data.ram) {
      ramElement.textContent = `RAM: ${data.ram.used} / ${data.ram.total} (${data.ram.percentage}%)`;
      ramElement.style.background = data.ram.percentage > 80 ? '#ff4444' : '#90EE90';
    }
    
    // Atualizar LND
    const lndElement = document.getElementById('lnd');
    if (data.lnd) {
      lndElement.textContent = `LND: ${data.lnd.status} | Synced: ${data.lnd.synced ? 'Sim' : 'Não'}`;
      lndElement.style.background = data.lnd.status === 'running' ? '#90EE90' : '#ff4444';
    }
    
    // Atualizar Bitcoind
    const bitcoindElement = document.getElementById('bitcoind');
    if (data.bitcoind) {
      bitcoindElement.textContent = `Bitcoind: ${data.bitcoind.status} | Blocks: ${data.bitcoind.blocks}`;
      bitcoindElement.style.background = data.bitcoind.status === 'running' ? '#90EE90' : '#ff4444';
    }

    // Atualizar Blockchain
    const blockchainElement = document.getElementById('blockchain');
    if (data.blockchain) {
      blockchainElement.textContent = `Blockchain: ${data.blockchain.size} | Progress: ${data.blockchain.progress}%`;
      blockchainElement.style.background = data.blockchain.progress >= 99.9 ? '#90EE90' : '#FFD700';
    }
    
  } catch (error) {
    console.error('Erro ao carregar status do sistema:', error);
    document.getElementById('cpu').textContent = 'CPU: Erro ao carregar';
    document.getElementById('ram').textContent = 'RAM: Erro ao carregar';
    document.getElementById('lnd').textContent = 'LND: Erro ao carregar';
    document.getElementById('bitcoind').textContent = 'Bitcoind: Erro ao carregar';
    document.getElementById('blockchain').textContent = 'Blockchain: Erro ao carregar';
  }
}

// Inicializar quando a página carregar
document.addEventListener('DOMContentLoaded', function() {
  // Carregar status inicial
  loadServicesStatus();
  loadSystemStatus();
  
  // Atualizar status a cada 10 segundos
  setInterval(loadSystemStatus, 10000);
  
  // Atualizar status dos serviços a cada 5 segundos
  setInterval(loadServicesStatus, 5000);
  
  // Add click handler for terminal web button
  const terminalBtn = document.querySelector('.terminal-web-btn');
  if (terminalBtn) {
    terminalBtn.addEventListener('click', openTerminalModal);
  }
  
  // Add click handler for close button
  const closeBtn = document.querySelector('.terminal-close');
  if (closeBtn) {
    closeBtn.addEventListener('click', closeTerminalModal);
  }
});

// Debug log to verify script loading
console.log('BRLN-OS Config script loaded successfully');
