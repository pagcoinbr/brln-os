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
  // Use HTTPS proxy path for GoTTY terminal (avoids mixed content)
  const url = `${window.location.protocol}//${window.location.host}/terminal/`;
  
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

// Função para abrir página de carteira com integrations
function openWalletPage() {
  // Navigate to wallet page with parameter to show integrations
  const walletUrl = `${window.location.protocol}//${window.location.host}/pages/components/wallet/wallet.html?showIntegrations=true`;
  window.open(walletUrl, '_blank');
}

window.openWalletPage = openWalletPage;

// Setup close button handler
document.addEventListener('DOMContentLoaded', function() {
  const closeBtn = document.querySelector('.terminal-close');
  if (closeBtn) {
    closeBtn.addEventListener('click', closeTerminalModal);
  }
});

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
    console.log('Fazendo fetch para: /api/v1/system/services');
    const response = await fetch('/api/v1/system/services', {
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

// Check LND installation status
async function checkLNDInstallation() {
  try {
    const response = await fetch('/api/v1/system/check-lnd-installation', {
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
    console.log('LND Installation Status:', data);
    
    return {
      hasLNDDirectory: data.has_lnd_directory || false,
      lndInSystemPath: data.lnd_in_system_path || false,
      lndInstalled: data.lnd_installed || false
    };
  } catch (error) {
    console.error('Error checking LND installation:', error);
    return {
      hasLNDDirectory: false,
      lndInSystemPath: false,
      lndInstalled: false
    };
  }
}

// Check wallet configuration status
async function checkWalletStatus() {
  try {
    const response = await fetch('/api/v1/wallet/system-default', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    });
    
    const data = await response.json();
    
    if (response.ok && data.status === 'success') {
      return {
        hasWallet: true,
        walletId: data.wallet_id
      };
    } else {
      return {
        hasWallet: false
      };
    }
  } catch (error) {
    console.error('Error checking wallet status:', error);
    return {
      hasWallet: false
    };
  }
}

// Perform initial setup check and redirect if needed
async function checkInitialSetup() {
  console.log('Checking initial setup status...');
  
  // Check LND installation
  const lndStatus = await checkLNDInstallation();
  
  // Scenario 1: Fresh installation - no LND directory and lnd not in system
  if (!lndStatus.hasLNDDirectory && !lndStatus.lndInSystemPath) {
    console.log('Fresh installation detected - redirecting to terminal setup');
    showSetupNotification('Sistema não configurado - redirecionando para setup inicial...', false);
    setTimeout(() => {
      window.top.location.href = '/terminal/?cmd=cd%20/root/brln-os%20%26%26%20bash%20scripts/menu.sh';
    }, 2000);
    return false;
  }
  
  // Scenario 2: LND installed but no wallet configured
  const walletStatus = await checkWalletStatus();
  if (!walletStatus.hasWallet) {
    console.log('LND installed but no wallet - redirecting to wallet setup');
    showSetupNotification('LND instalado - configure sua wallet...', false);
    setTimeout(() => {
      if (window.top !== window.self) {
        window.top.location.href = '/pages/components/wallet/wallet.html';
      } else {
        window.location.href = '/pages/components/wallet/wallet.html';
      }
    }, 2000);
    return false;
  }
  
  console.log('System is configured - loading normally');
  return true;
}

// Show setup notification
function showSetupNotification(message, isSuccess = false) {
  const notification = document.createElement('div');
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: ${isSuccess ? '#28a745' : '#ff9800'};
    color: white;
    padding: 15px 25px;
    border-radius: 8px;
    z-index: 10000;
    font-family: Arial, sans-serif;
    font-size: 14px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.3);
    max-width: 90%;
    text-align: center;
  `;
  notification.textContent = message;
  document.body.appendChild(notification);
}

// Carregar status do sistema
async function loadSystemStatus() {
  try {
    console.log('Fazendo fetch para: /api/v1/system/status');
    const response = await fetch('/api/v1/system/status', {
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

// Password Manager Backup Functions
async function loadBackupInfo() {
  try {
    console.log('Loading password manager backup info...');
    const response = await fetch('/api/v1/system/passwords/backup/info', {
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
    console.log('Backup info:', data);
    
    // Update UI elements
    const sizeElement = document.getElementById('backup-size');
    const countElement = document.getElementById('backup-count');
    const dateElement = document.getElementById('backup-date');
    
    if (sizeElement) {
      sizeElement.textContent = data.file_size_human || 'N/A';
    }
    if (countElement) {
      countElement.textContent = data.stored_passwords !== undefined ? data.stored_passwords : 'N/A';
    }
    if (dateElement) {
      // Format the date nicely
      if (data.last_modified) {
        const date = new Date(data.last_modified);
        dateElement.textContent = date.toLocaleString();
      } else {
        dateElement.textContent = 'N/A';
      }
    }
    
  } catch (error) {
    console.error('Error loading backup info:', error);
    document.getElementById('backup-size').textContent = 'Error';
    document.getElementById('backup-count').textContent = 'Error';
    document.getElementById('backup-date').textContent = 'Error';
  }
}

async function downloadBackup() {
  try {
    console.log('Downloading password manager backup...');
    const response = await fetch('/api/v1/system/passwords/backup', {
      method: 'GET',
      credentials: 'same-origin'
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    // Get filename from Content-Disposition header
    const contentDisposition = response.headers.get('Content-Disposition');
    let filename = 'brln-passwords-backup.db';
    if (contentDisposition) {
      const match = contentDisposition.match(/filename="(.+)"/);
      if (match) {
        filename = match[1];
      }
    }
    
    // Download the file
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
    
    console.log('Backup downloaded successfully:', filename);
    alert('Backup downloaded successfully!');
    
  } catch (error) {
    console.error('Error downloading backup:', error);
    alert(`Error downloading backup: ${error.message}`);
  }
}

// Make backup functions globally accessible
window.loadBackupInfo = loadBackupInfo;
window.downloadBackup = downloadBackup;

// Inicializar quando a página carregar
document.addEventListener('DOMContentLoaded', async function() {
  // Perform initial setup check
  const isConfigured = await checkInitialSetup();
  
  // Only load page content if system is configured
  if (!isConfigured) {
    console.log('System not configured - skipping page load');
    return;
  }
  
  // Carregar status inicial
  loadServicesStatus();
  loadSystemStatus();
  loadBackupInfo();
  
  // Atualizar status a cada 10 segundos
  setInterval(loadSystemStatus, 10000);
  
  // Atualizar status dos serviços a cada 5 segundos
  setInterval(loadServicesStatus, 5000);
  
  // Atualizar backup info a cada 30 segundos
  setInterval(loadBackupInfo, 30000);
  
  // Add click handler for terminal web buttons (excluding those with onclick)
  const terminalBtns = document.querySelectorAll('.terminal-web-btn:not([onclick])');
  terminalBtns.forEach(btn => {
    btn.addEventListener('click', openTerminalModal);
  });
  
  // Add click handler for close button
  const closeBtn = document.querySelector('.terminal-close');
  if (closeBtn) {
    closeBtn.addEventListener('click', closeTerminalModal);
  }
});

// Debug log to verify script loading
console.log('BRLN-OS Config script loaded successfully');
