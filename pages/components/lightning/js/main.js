// Central de Controle Lightning BRLN-OS
// Integração com API local para funcionalidades Lightning Network

// Base URL da API
const API_BASE_URL = '/api/v1';

// Variáveis globais
let currentConversation = null;
let conversations = new Map();
let lastMessageCheck = Date.now();

// === INICIALIZAÇÃO ===
document.addEventListener('DOMContentLoaded', function() {
  initializePage();
  setupEventListeners();
  
  // Atualizar dados a cada 10 segundos
  setInterval(updateAllData, 10000);
  
  // Verificar novas mensagens a cada 5 segundos
  setInterval(checkNewMessages, 5000);
  
  // Carregar conversas do localStorage
  loadConversationsFromStorage();
});

function abrirApp(porta) {
  const ip = window.location.hostname;
  window.open(`https://${ip}:${porta}`, '_blank');
}

function initializePage() {
  // Carregar todos os dados iniciais
  updateAllData();
}

function setupEventListeners() {
  // Botão para nova conversa
  document.getElementById('newChatButton').addEventListener('click', startNewConversation);
  
  // Input para nova conversa (Enter)
  document.getElementById('newChatNode').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      startNewConversation();
    }
  });
  
  // Botão enviar mensagem
  document.getElementById('sendMessageButton').addEventListener('click', sendMessage);
  
  // Input mensagem (Enter)
  document.getElementById('messageInput').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      sendMessage();
    }
  });
  
  // Botão de notificações
  document.getElementById('notificationButton').addEventListener('click', requestNotificationPermission);
  
  // Atualizar status das notificações
  updateNotificationButton();
}

// === FUNÇÕES DE ATUALIZAÇÃO DE DADOS ===
async function updateAllData() {
  await Promise.all([
    updateLightningBalance(),
    updateChannels(),
    updatePeers()
  ]);
}

async function updateLightningBalance() {
  try {
    // Buscar saldo dos canais Lightning
    const response = await fetch(`${API_BASE_URL}/wallet/balance/lightning`);
    if (!response.ok) throw new Error('Erro ao buscar saldo Lightning');
    
    const data = await response.json();
    
    if (data.status === 'success') {
      document.getElementById('lightningBalance').textContent = 
        `${parseInt(data.balance || 0).toLocaleString()} sats`;
      document.getElementById('pendingBalance').textContent = 
        `${parseInt(data.pending_open_balance || 0).toLocaleString()} sats pendente`;
    } else {
      document.getElementById('lightningBalance').textContent = 'Erro ao carregar';
      document.getElementById('pendingBalance').textContent = '';
    }
  } catch (error) {
    console.error('Erro ao buscar saldo Lightning:', error);
    document.getElementById('lightningBalance').textContent = 'Erro ao carregar';
    document.getElementById('pendingBalance').textContent = '';
  }
}

async function updateChannels() {
  try {
    const response = await fetch(`${API_BASE_URL}/lightning/channels`);
    if (!response.ok) throw new Error('Erro ao buscar canais');
    
    const data = await response.json();
    const container = document.getElementById('channelsContainer');
    
    if (data.status === 'success' && data.channels && data.channels.channels) {
      const channels = data.channels.channels;
      
      if (channels.length === 0) {
        container.innerHTML = `
          <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
            Nenhum canal encontrado
          </div>`;
      } else {
        container.innerHTML = channels.map(channel => createChannelHTML(channel)).join('');
      }
    } else {
      container.innerHTML = `
        <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
          ${data.error || 'Erro ao carregar canais'}
        </div>`;
    }
  } catch (error) {
    console.error('Erro ao buscar canais:', error);
    document.getElementById('channelsContainer').innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
        Erro ao carregar canais
      </div>`;
  }
}

async function updatePeers() {
  try {
    const response = await fetch(`${API_BASE_URL}/lightning/peers`);
    if (!response.ok) throw new Error('Erro ao buscar peers');
    
    const data = await response.json();
    const container = document.getElementById('peersContainer');
    
    if (data.status === 'success' && data.peers) {
      const peers = data.peers;
      
      // Atualizar contador de peers no saldo
      document.getElementById('peersConnected').textContent = 
        `${peers.length} peers`;
      
      if (peers.length === 0) {
        container.innerHTML = `
          <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
            Nenhum peer conectado
          </div>`;
      } else {
        container.innerHTML = peers.map(peer => createPeerHTML(peer)).join('');
      }
    } else {
      document.getElementById('peersConnected').textContent = '0 peers';
      container.innerHTML = `
        <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
          ${data.error || 'Erro ao carregar peers'}
        </div>`;
    }
  } catch (error) {
    console.error('Erro ao buscar peers:', error);
    document.getElementById('peersConnected').textContent = 'Erro';
    document.getElementById('peersContainer').innerHTML = `
      <div style="width: 100%; text-align: center; padding: 40px; color: #666; font-style: italic;">
        Erro ao carregar peers
      </div>`;
  }
}

// === FUNÇÕES DE CRIAÇÃO DE HTML ===
function createChannelHTML(channel) {
  const localBalance = parseInt(channel.local_balance || 0);
  const remoteBalance = parseInt(channel.remote_balance || 0);
  const capacity = parseInt(channel.capacity || 0);
  
  const localPercentage = capacity > 0 ? (localBalance / capacity) * 100 : 0;
  const peerPubkey = channel.remote_pubkey || 'Desconhecido';
  const peerShort = peerPubkey.substring(0, 16) + '...';
  
  const isActive = channel.active === true || channel.active === 'true';
  
  return `
    <div class="channel-item">
      <div class="channel-header">
        <div class="channel-peer" title="${peerPubkey}">
          Peer: ${peerShort}
        </div>
        <div class="channel-status ${isActive ? 'active' : 'inactive'}">
          ${isActive ? 'ATIVO' : 'INATIVO'}
        </div>
      </div>
      
      <div class="channel-liquidity">
        <div class="liquidity-label">Liquidez do Canal</div>
        <div class="liquidity-bar">
          <div class="liquidity-local" style="width: ${localPercentage}%"></div>
        </div>
        <div class="liquidity-values">
          <div>Local: ${localBalance.toLocaleString()} sats</div>
          <div>Capacidade: ${capacity.toLocaleString()} sats</div>
          <div>Remoto: ${remoteBalance.toLocaleString()} sats</div>
        </div>
      </div>
    </div>`;
}

function createPeerHTML(peer) {
  const pubkey = peer.pub_key || 'Desconhecido';
  const address = peer.address || 'N/A';
  
  return `
    <div class="peer-item">
      <div class="peer-pubkey" title="${pubkey}">
        ${pubkey.substring(0, 32)}...
      </div>
      <div class="peer-info">
        <div class="peer-address">${address}</div>
        <div class="peer-actions">
          <div class="peer-status">CONECTADO</div>
          <button class="copy-peer-button" onclick="copyPeerInfo('${pubkey}')" title="Copiar Node ID para Chat">
            📋 Chat
          </button>
        </div>
      </div>
    </div>`;
}

// === FUNÇÕES DE CHAT ===
function startNewConversation() {
  const nodeInput = document.getElementById('newChatNode');
  const nodeId = nodeInput.value.trim();
  
  if (!nodeId) {
    alert('Por favor, insira o Node ID do destinatário');
    return;
  }
  
  if (nodeId.length !== 66) {
    alert('Node ID deve ter 66 caracteres');
    return;
  }
  
  // Verificar se já existe conversa com este node
  if (conversations.has(nodeId)) {
    selectConversation(nodeId);
    nodeInput.value = '';
    return;
  }
  
  // Criar nova conversa
  const conversation = {
    nodeId: nodeId,
    messages: [],
    lastActivity: Date.now(),
    unread: 0
  };
  
  conversations.set(nodeId, conversation);
  saveConversationsToStorage();
  updateConversationsList();
  selectConversation(nodeId);
  
  nodeInput.value = '';
}

function selectConversation(nodeId) {
  currentConversation = nodeId;
  
  // Atualizar UI da lista de conversas
  updateConversationsList();
  
  // Mostrar mensagens da conversa
  displayMessages(nodeId);
  
  // Mostrar área de input
  document.getElementById('chatInputContainer').style.display = 'block';
  
  // Marcar como lida
  if (conversations.has(nodeId)) {
    conversations.get(nodeId).unread = 0;
    saveConversationsToStorage();
    updateConversationsList();
  }
}

function updateConversationsList() {
  const container = document.getElementById('conversationList');
  
  if (conversations.size === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 20px; color: #666; font-style: italic;">
        Nenhuma conversa ativa
      </div>`;
    return;
  }
  
  const conversationArray = Array.from(conversations.entries())
    .sort(([,a], [,b]) => b.lastActivity - a.lastActivity);
  
  container.innerHTML = conversationArray.map(([nodeId, conv]) => 
    createConversationHTML(nodeId, conv)).join('');
  
  // Adicionar event listeners
  container.querySelectorAll('.conversation-item').forEach(item => {
    item.addEventListener('click', () => {
      const nodeId = item.dataset.nodeId;
      selectConversation(nodeId);
    });
  });
}

function createConversationHTML(nodeId, conversation) {
  const isActive = currentConversation === nodeId;
  const lastMessage = conversation.messages.length > 0 
    ? conversation.messages[conversation.messages.length - 1] 
    : null;
  
  const preview = lastMessage 
    ? (lastMessage.message.length > 30 
       ? lastMessage.message.substring(0, 30) + '...' 
       : lastMessage.message)
    : 'Nova conversa';
    
  const timeStr = lastMessage 
    ? new Date(lastMessage.timestamp).toLocaleTimeString('pt-BR', { 
        hour: '2-digit', 
        minute: '2-digit' 
      })
    : '';
  
  const nodeShort = nodeId.substring(0, 16) + '...';
  const unreadClass = conversation.unread > 0 ? 'conversation-unread' : '';
  
  return `
    <div class="conversation-item ${isActive ? 'active' : ''} ${unreadClass}" 
         data-node-id="${nodeId}">
      <div class="conversation-node" title="${nodeId}">
        ${nodeShort}
      </div>
      <div class="conversation-preview">${preview}</div>
      <div class="conversation-time">${timeStr}</div>
    </div>`;
}

function displayMessages(nodeId) {
  const container = document.getElementById('chatMessages');
  const conversation = conversations.get(nodeId);
  
  if (!conversation || conversation.messages.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #666; font-style: italic;">
        Nenhuma mensagem ainda. Envie uma mensagem para começar!
      </div>`;
    return;
  }
  
  container.innerHTML = conversation.messages.map(msg => createMessageHTML(msg)).join('');
  
  // Scroll para baixo
  container.scrollTop = container.scrollHeight;
}

function createMessageHTML(message) {
  const isSent = message.type === 'sent';
  const time = new Date(message.timestamp).toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit'
  });
  
  let statusHTML = '';
  if (isSent) {
    let statusClass = message.status || 'pending';
    let statusText = '';
    
    switch (statusClass) {
      case 'confirmed':
        statusText = '✓ Confirmado';
        break;
      case 'pending':
        statusText = '⏳ Enviando...';
        break;
      case 'failed':
        statusText = '✗ Falhou';
        break;
    }
    
    statusHTML = `<div class="message-status ${statusClass}">${statusText}</div>`;
  }
  
  return `
    <div class="message-item ${isSent ? 'sent' : 'received'}">
      <div class="message-bubble">
        ${message.message}
      </div>
      <div class="message-time">${time}</div>
      ${statusHTML}
    </div>`;
}

async function sendMessage() {
  if (!currentConversation) {
    alert('Selecione uma conversa primeiro');
    return;
  }
  
  const input = document.getElementById('messageInput');
  const message = input.value.trim();
  
  if (!message) {
    alert('Digite uma mensagem');
    return;
  }
  
  if (message.length > 500) {
    alert('Mensagem muito longa (máximo 500 caracteres)');
    return;
  }
  
  const sendButton = document.getElementById('sendMessageButton');
  sendButton.disabled = true;
  sendButton.textContent = 'Enviando...';
  
  try {
    // Adicionar mensagem localmente primeiro
    const messageObj = {
      type: 'sent',
      message: message,
      timestamp: Date.now(),
      status: 'pending'
    };
    
    const conversation = conversations.get(currentConversation);
    conversation.messages.push(messageObj);
    conversation.lastActivity = Date.now();
    saveConversationsToStorage();
    
    // Atualizar display
    displayMessages(currentConversation);
    input.value = '';
    
    // Enviar via keysend
    const response = await fetch(`${API_BASE_URL}/lightning/payments/keysend`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        dest: currentConversation,
        amt: 1, // 1 satoshi
        custom_records: {
          '34349334': btoa(message) // TLV record para mensagem
        }
      })
    });
    
    const result = await response.json();
    
    // Atualizar status da mensagem
    const lastMessage = conversation.messages[conversation.messages.length - 1];
    if (result.status === 'success') {
      lastMessage.status = 'confirmed';
      lastMessage.payment_hash = result.payment_hash;
    } else {
      lastMessage.status = 'failed';
      lastMessage.error = result.error;
    }
    
    saveConversationsToStorage();
    displayMessages(currentConversation);
    
    if (result.status !== 'success') {
      alert(`Erro ao enviar mensagem: ${result.error}`);
    }
    
  } catch (error) {
    console.error('Erro ao enviar mensagem:', error);
    
    // Atualizar status para erro
    const conversation = conversations.get(currentConversation);
    const lastMessage = conversation.messages[conversation.messages.length - 1];
    lastMessage.status = 'failed';
    lastMessage.error = error.message;
    
    saveConversationsToStorage();
    displayMessages(currentConversation);
    
    alert(`Erro ao enviar mensagem: ${error.message}`);
  } finally {
    sendButton.disabled = false;
    sendButton.textContent = 'Enviar';
  }
}

// === FUNÇÕES DE PERSISTÊNCIA ===
function saveConversationsToStorage() {
  const data = Object.fromEntries(conversations);
  localStorage.setItem('lightning_conversations', JSON.stringify(data));
}

function loadConversationsFromStorage() {
  try {
    const data = localStorage.getItem('lightning_conversations');
    if (data) {
      const parsed = JSON.parse(data);
      conversations = new Map(Object.entries(parsed));
      updateConversationsList();
    }
  } catch (error) {
    console.error('Erro ao carregar conversas:', error);
    conversations = new Map();
  }
}

// === VERIFICAÇÃO DE NOVAS MENSAGENS ===
async function checkNewMessages() {
  try {
    // Verificar notificações na API
    const response = await fetch(`${API_BASE_URL}/lightning/chat/notifications`);
    if (response.ok) {
      const data = await response.json();
      if (data.status === 'success' && data.unread_count > 0) {
        // Notificar o header se há mensagens novas
        if (parent && parent.notifyLightningMessage) {
          parent.notifyLightningMessage();
        }
      }
    }
  } catch (error) {
    console.error('Erro ao verificar novas mensagens:', error);
  }
}

// Função para adicionar mensagem recebida (será chamada pelo sistema de notificações)
function addReceivedMessage(nodeId, message, timestamp) {
  let conversation = conversations.get(nodeId);
  
  if (!conversation) {
    // Criar nova conversa para sender desconhecido
    conversation = {
      nodeId: nodeId,
      messages: [],
      lastActivity: timestamp || Date.now(),
      unread: 0
    };
    conversations.set(nodeId, conversation);
  }
  
  const messageObj = {
    type: 'received',
    message: message,
    timestamp: timestamp || Date.now()
  };
  
  conversation.messages.push(messageObj);
  conversation.lastActivity = messageObj.timestamp;
  
  // Marcar como não lida se não for a conversa atual
  if (currentConversation !== nodeId) {
    conversation.unread++;
    notifyNewMessage();
  }
  
  saveConversationsToStorage();
  updateConversationsList();
  
  // Se é a conversa ativa, atualizar display
  if (currentConversation === nodeId) {
    displayMessages(nodeId);
  }
}

function notifyNewMessage() {
  // Notificar o header sobre nova mensagem
  if (parent && parent.notifyLightningMessage) {
    parent.notifyLightningMessage();
  }
  
  // Mostrar notificação do browser se permitido
  if (Notification.permission === 'granted') {
    new Notification('💡 Nova mensagem Lightning', {
      body: 'Você recebeu uma nova mensagem via Lightning Network',
      icon: '/favicon.ico',
      tag: 'lightning-message',
      requireInteraction: false
    });
  }
}

// === SISTEMA DE NOTIFICAÇÕES DO NAVEGADOR ===
function requestNotificationPermission() {
  const button = document.getElementById('notificationButton');
  const isSecureContext = window.isSecureContext || location.protocol === 'https:' || location.hostname === 'localhost';
  
  if (!('Notification' in window)) {
    showNotification('Seu navegador não suporta notificações', 'error');
    return;
  }
  
  // Verificar se estamos em contexto seguro
  if (!isSecureContext) {
    showNotification('Notificações só funcionam em HTTPS ou localhost. Acesse via HTTPS para ativar.', 'error');
    return;
  }
  
  if (Notification.permission === 'granted') {
    // Mostrar notificação de teste
    new Notification('✅ Notificações ativas', {
      body: 'Você receberá notificações de novas mensagens Lightning',
      icon: '/favicon.ico',
      tag: 'test-notification'
    });
    showNotification('Notificações já estão ativas!', 'success');
    return;
  }
  
  if (Notification.permission === 'denied') {
    showNotification('Notificações foram negadas. Habilite nas configurações do navegador.', 'error');
    return;
  }
  
  // Solicitar permissão
  button.textContent = '⏳ Aguardando...';
  button.disabled = true;
  
  Notification.requestPermission().then(function(permission) {
    if (permission === 'granted') {
      showNotification('Notificações habilitadas com sucesso!', 'success');
      // Mostrar notificação de boas-vindas
      new Notification('🎉 Notificações Lightning ativas', {
        body: 'Agora você receberá alertas de novas mensagens',
        icon: '/favicon.ico',
        tag: 'welcome-notification'
      });
    } else if (permission === 'denied') {
      showNotification('Notificações foram negadas', 'error');
    } else {
      showNotification('Permissão de notificação não foi concedida', 'error');
    }
    
    button.disabled = false;
    updateNotificationButton();
  }).catch(function(error) {
    console.error('Erro ao solicitar permissão de notificação:', error);
    showNotification('Erro: Notificações não disponíveis neste contexto', 'error');
    button.disabled = false;
    updateNotificationButton();
  });
}

function updateNotificationButton() {
  const button = document.getElementById('notificationButton');
  const isSecureContext = window.isSecureContext || location.protocol === 'https:' || location.hostname === 'localhost';
  
  if (!('Notification' in window)) {
    button.textContent = '❌ Não suportado';
    button.className = 'notification-button denied';
    button.disabled = true;
    button.title = 'Seu navegador não suporta notificações';
    return;
  }
  
  // Em contexto não seguro (HTTP), as notificações não funcionam
  if (!isSecureContext) {
    button.textContent = '🔒 Requer HTTPS';
    button.className = 'notification-button denied';
    button.disabled = true;
    button.title = 'Notificações só funcionam em HTTPS ou localhost. Acesse via HTTPS para usar.';
    return;
  }
  
  switch (Notification.permission) {
    case 'granted':
      button.textContent = '✅ Ativas';
      button.className = 'notification-button granted';
      button.title = 'Notificações estão ativas. Clique para testar.';
      button.disabled = false;
      break;
    case 'denied':
      button.textContent = '❌ Negadas';
      button.className = 'notification-button denied';
      button.title = 'Notificações negadas. Habilite nas configurações do navegador.';
      button.disabled = false;
      break;
    default: // 'default'
      button.textContent = '🔔 Ativar';
      button.className = 'notification-button';
      button.title = 'Clique para ativar notificações de novas mensagens';
      button.disabled = false;
      break;
  }
}

// Verificar permissões no carregamento da página
document.addEventListener('visibilitychange', function() {
  if (!document.hidden) {
    updateNotificationButton();
  }
});

// Inicialização das notificações - não pedir automaticamente
// Deixar o usuário decidir quando quer ativar

// === FUNÇÕES UTILITÁRIAS ===
function copyPeerInfo(pubkey) {
  // Preencher automaticamente o campo de novo chat primeiro
  const chatInput = document.getElementById('newChatNode');
  if (chatInput) {
    chatInput.value = pubkey;
    chatInput.focus();
  }
  
  // Tentar copiar para a área de transferência se disponível
  if (typeof navigator.clipboard !== 'undefined' && window.isSecureContext) {
    // Ambiente seguro (HTTPS ou localhost) - usar clipboard API
    navigator.clipboard.writeText(pubkey).then(() => {
      showNotification('Node ID copiado e preenchido no chat!', 'success');
    }).catch(err => {
      console.error('Erro ao copiar:', err);
      showNotification('Node ID preenchido no chat!', 'success');
    });
  } else {
    // Fallback para ambientes HTTP - usar método alternativo
    const textArea = document.createElement('textarea');
    textArea.value = pubkey;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    
    try {
      const successful = document.execCommand('copy');
      document.body.removeChild(textArea);
      if (successful) {
        showNotification('Node ID copiado e preenchido no chat!', 'success');
      } else {
        showNotification('Node ID preenchido no chat! (Copiar manualmente se necessário)', 'info');
      }
    } catch (err) {
      document.body.removeChild(textArea);
      console.error('Erro no fallback de cópia:', err);
      showNotification('Node ID preenchido no chat! (Copiar manualmente se necessário)', 'info');
    }
  }
}

function showNotification(message, type = 'info') {
  // Criar elemento de notificação
  const notification = document.createElement('div');
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: ${type === 'error' ? '#ff4444' : type === 'success' ? '#44ff44' : '#4444ff'};
    color: white;
    padding: 15px 20px;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    z-index: 9999;
    font-weight: bold;
    max-width: 300px;
  `;
  notification.textContent = message;
  
  document.body.appendChild(notification);
  
  // Remover após 3 segundos
  setTimeout(() => {
    if (notification.parentNode) {
      notification.parentNode.removeChild(notification);
    }
  }, 3000);
}
