// ============================================
// PAGCOIN.ORG - JavaScript Functionality
// ============================================

// ============================================
// DIGITAL CLOCK
// ============================================
function updateDigitalClock() {
  const now = new Date();
  
  // Format date: DD/MM/YYYY
  const day = String(now.getDate()).padStart(2, '0');
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const year = now.getFullYear();
  const dateString = `${day}/${month}/${year}`;
  
  // Format time: HH:MM:SS
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  const timeString = `${hours}:${minutes}:${seconds}`;
  
  // Update DOM elements
  const dateElement = document.getElementById('clockDate');
  const timeElement = document.getElementById('clockTime');
  
  if (dateElement) dateElement.textContent = dateString;
  if (timeElement) timeElement.textContent = timeString;
}

// Configuration
const CONFIG = {
  // API endpoints for real Bitcoin data (optional integration)
  BITCOIN_API: "https://api.coindesk.com/v1/bpi/currentprice.json",
  BLOCKCHAIN_API: "https://blockchain.info/q",
  AMBOSS_API: "https://api.amboss.space/graphql",

  // Refresh intervals (in milliseconds)
  PRICE_REFRESH_INTERVAL: 60000, // 1 minute
  BLOCK_REFRESH_INTERVAL: 30000, // 30 seconds
};

// ============================================
// BITCOIN PRICE FETCHER
// ============================================
class BitcoinPriceFetcher {
  constructor() {
    this.priceCache = {
      brl: null,
      usd: null,
    };
  }

  /**
   * Fetch real-time Bitcoin price from multiple APIs
   */
  async fetchBitcoinPrice() {
    try {
      // Tentar AwesomeAPI (API brasileira)
      const response = await fetch(
        "https://economia.awesomeapi.com.br/json/last/BTC-BRL,BTC-USD"
      );

      if (response.ok) {
        const data = await response.json();

        if (data.BTCBRL && data.BTCUSD) {
          const brlPrice = parseFloat(data.BTCBRL.bid);
          const usdPrice = parseFloat(data.BTCUSD.bid);

          this.priceCache = {
            brl: `R$ ${this.formatPrice(brlPrice)}`,
            usd: `$${this.formatPrice(usdPrice)}`,
          };

          return this.priceCache;
        }
      }
    } catch (error) {
      console.warn("Error with AwesomeAPI, trying CoinDesk:", error);
    }

    try {
      // Fallback: CoinDesk API
      const response = await fetch(CONFIG.BITCOIN_API);

      if (!response.ok) {
        throw new Error("CoinDesk API failed");
      }

      const data = await response.json();

      // Extract USD price and remove commas
      const usdPriceStr = data.bpi.USD.rate.replace(",", "");
      const usdPrice = parseFloat(usdPriceStr);

      // Fetch BRL price
      const brlPrice = await this.fetchBRLPrice(usdPrice);

      this.priceCache = {
        brl: `R$ ${this.formatPrice(brlPrice)}`,
        usd: `$${this.formatPrice(usdPrice)}`,
      };

      return this.priceCache;
    } catch (error) {
      console.error("Error fetching Bitcoin price from all sources:", error);

      // Se não houver cache, mostrar erro
      if (!this.priceCache.brl || !this.priceCache.usd) {
        this.priceCache = {
          brl: "Erro ao carregar",
          usd: "Erro ao carregar",
        };
      }

      return this.priceCache;
    }
  }

  /**
   * Fetch BRL conversion rate
   */
  async fetchBRLPrice(usdPrice) {
    try {
      const response = await fetch(
        "https://api.exchangerate-api.com/v4/latest/USD"
      );
      const data = await response.json();
      const brlRate = data.rates.BRL;
      return usdPrice * brlRate;
    } catch (error) {
      console.error("Error fetching BRL rate:", error);
      throw error;
    }
  }

  /**
   * Format price with thousands separator
   */
  formatPrice(price) {
    return parseFloat(price).toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }

  /**
   * Update DOM with fetched prices
   */
  async updatePriceDisplay() {
    const prices = await this.fetchBitcoinPrice();
    const priceBRLElement = document.getElementById("priceBRL");
    const priceUSDElement = document.getElementById("priceUSD");

    if (priceBRLElement) {
      priceBRLElement.textContent = prices.brl;
    }
    if (priceUSDElement) {
      priceUSDElement.textContent = prices.usd;
    }
  }
}

// ============================================
// BLOCKCHAIN DATA FETCHER
// ============================================
class BlockchainDataFetcher {
  constructor() {
    this.blockCache = {
      number: null,
      fee: null,
    };
  }

  /**
   * Fetch latest Bitcoin block information
   */
  async fetchLatestBlock() {
    try {
      // Get latest block height
      const blockHeightResponse = await fetch(
        "https://blockchain.info/q/getblockcount"
      );
      const blockNumber = await blockHeightResponse.text();

      // Get current fee estimate (in sat/vB)
      const feeResponse = await fetch(
        "https://mempool.space/api/v1/fees/recommended"
      );
      const feeData = await feeResponse.json();
      const fastestFee = Math.round(feeData.fastestFee);

      this.blockCache = {
        number: this.formatBlockNumber(blockNumber),
        fee: fastestFee.toString(),
      };

      return this.blockCache;
    } catch (error) {
      console.error("Error fetching blockchain data:", error);
      return this.blockCache;
    }
  }

  /**
   * Format block number with thousands separator
   */
  formatBlockNumber(number) {
    return parseInt(number).toLocaleString("pt-BR");
  }

  /**
   * Update DOM with block information
   */
  async updateBlockDisplay() {
    const blockData = await this.fetchLatestBlock();
    const blockNumberElement = document.getElementById("blockNumber");
    const blockFeeElement = document.getElementById("blockFee");

    if (blockNumberElement) {
      blockNumberElement.textContent = blockData.number;
    }
    if (blockFeeElement) {
      blockFeeElement.textContent = blockData.fee;
    }
  }
}

// ============================================
// NAVIGATION HANDLER
// ============================================
class NavigationHandler {
  constructor() {
    this.navLinks = document.querySelectorAll(".nav-link");
    this.init();
  }

  init() {
    this.navLinks.forEach((link) => {
      link.addEventListener("click", (e) => this.handleNavigation(e));
    });
    this.updateActiveLink();
    window.addEventListener("scroll", () => this.updateActiveLink());
  }

  handleNavigation(event) {
    const link = event.target;
    const href = link.getAttribute("href");

    if (href && href.startsWith("#")) {
      event.preventDefault();

      // Remove active class from all links
      this.navLinks.forEach((l) => l.classList.remove("active"));
      link.classList.add("active");

      // Scroll to section
      const sectionId = href.substring(1);
      const section = document.getElementById(sectionId);

      if (section) {
        section.scrollIntoView({ behavior: "smooth" });
      }
    }
  }

  updateActiveLink() {
    const sections = document.querySelectorAll("section[id]");
    let currentSection = "";

    sections.forEach((section) => {
      const sectionTop = section.offsetTop;
      const sectionHeight = section.clientHeight;

      if (window.pageYOffset >= sectionTop - 200) {
        currentSection = section.getAttribute("id");
      }
    });

    this.navLinks.forEach((link) => {
      link.classList.remove("active");
      if (link.getAttribute("href") === `#${currentSection}`) {
        link.classList.add("active");
      }
    });
  }
}

// ============================================
// SEARCH FUNCTIONALITY
// ============================================
class SearchHandler {
  constructor() {
    this.searchBtn = document.querySelector(".search-btn");
    this.init();
  }

  init() {
    if (this.searchBtn) {
      this.searchBtn.addEventListener("click", () => this.toggleSearch());
    }
  }

  toggleSearch() {
    // Create search modal
    const modal = document.createElement("div");
    modal.className = "search-modal";
    modal.innerHTML = `
            <div class="search-content">
                <input type="text" placeholder="Buscar..." class="search-input" autofocus>
                <button class="search-close">✕</button>
            </div>
        `;

    document.body.appendChild(modal);

    const input = modal.querySelector(".search-input");
    const closeBtn = modal.querySelector(".search-close");

    closeBtn.addEventListener("click", () => modal.remove());
    modal.addEventListener("click", (e) => {
      if (e.target === modal) modal.remove();
    });

    input.addEventListener("keydown", (e) => {
      if (e.key === "Escape") modal.remove();
    });
  }
}

// ============================================
// 3D BITCOIN CUBE ANIMATION
// ============================================
class BitcoinCubeAnimation {
  constructor(selector) {
    this.element = document.querySelector(selector);
    this.rotationX = 0;
    this.rotationY = 0;
    this.init();
  }

  init() {
    if (!this.element) return;

    this.animate();
    window.addEventListener("mousemove", (e) => this.onMouseMove(e));
  }

  animate() {
    this.rotationX += 0.5;
    this.rotationY += 0.7;

    if (this.element) {
      this.element.style.transform = `rotateX(${this.rotationX}deg) rotateY(${this.rotationY}deg)`;
    }

    requestAnimationFrame(() => this.animate());
  }

  onMouseMove(event) {
    const x = (event.clientX / window.innerWidth) * 360;
    const y = (event.clientY / window.innerHeight) * 360;

    if (this.element) {
      this.element.style.transform = `rotateX(${y}deg) rotateY(${x}deg)`;
    }
  }
}

// ============================================
// SCROLL ANIMATIONS
// ============================================
class ScrollAnimations {
  constructor() {
    this.observerOptions = {
      threshold: 0.1,
      rootMargin: "0px 0px -50px 0px",
    };
    this.init();
  }

  init() {
    const observer = new IntersectionObserver(
      (entries) => this.onIntersection(entries),
      this.observerOptions
    );

    // Observe all cards and sections
    document
      .querySelectorAll(".service-card, .content-section")
      .forEach((el) => {
        observer.observe(el);
      });
  }

  onIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("fade-in");
      }
    });
  }
}

// ============================================
// SMOOTH SCROLL BEHAVIOR
// ============================================
class SmoothScroll {
  constructor() {
    this.init();
  }

  init() {
    if ("scrollBehavior" in document.documentElement.style) {
      return; // Native smooth scroll is supported
    }

    // Polyfill for browsers that don't support smooth scroll
    document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
      anchor.addEventListener("click", (e) => {
        e.preventDefault();
        const target = document.querySelector(anchor.getAttribute("href"));
        if (target) {
          target.scrollIntoView({ behavior: "smooth" });
        }
      });
    });
  }
}

// ============================================
// LAZY LOADING IMAGES
// ============================================
class LazyLoadImages {
  constructor() {
    this.init();
  }

  init() {
    if ("IntersectionObserver" in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const img = entry.target;
            img.src = img.dataset.src;
            img.classList.remove("lazy");
            imageObserver.unobserve(img);
          }
        });
      });

      document.querySelectorAll("img[data-src]").forEach((img) => {
        imageObserver.observe(img);
      });
    }
  }
}

// ============================================
// LOCAL STORAGE CACHE MANAGER
// ============================================
class CacheManager {
  constructor() {
    this.prefix = "pagcoin_";
  }

  set(key, value, ttl = 300000) {
    // 5 minutes default
    const data = {
      value,
      timestamp: Date.now(),
      ttl,
    };
    localStorage.setItem(this.prefix + key, JSON.stringify(data));
  }

  get(key) {
    const item = localStorage.getItem(this.prefix + key);
    if (!item) return null;

    const data = JSON.parse(item);
    if (Date.now() - data.timestamp > data.ttl) {
      localStorage.removeItem(this.prefix + key);
      return null;
    }

    return data.value;
  }

  clear(key = null) {
    if (key) {
      localStorage.removeItem(this.prefix + key);
    } else {
      Object.keys(localStorage).forEach((k) => {
        if (k.startsWith(this.prefix)) {
          localStorage.removeItem(k);
        }
      });
    }
  }
}

// ============================================
// MAIN APPLICATION CLASS
// ============================================
class PagCoinApp {
  constructor() {
    this.cache = new CacheManager();
    this.priceFetcher = new BitcoinPriceFetcher();
    this.blockchainFetcher = new BlockchainDataFetcher();

    this.init();
  }

  async init() {
    // Initialize all components
    new NavigationHandler();
    new SearchHandler();
    new BitcoinCubeAnimation(".bitcoin-cube");
    new ScrollAnimations();
    new SmoothScroll();
    new LazyLoadImages();

    // Load initial data
    await this.loadData();

    // Set up refresh intervals
    this.setupRefreshIntervals();

    // Log initialization
    console.log("PagCoin Application initialized successfully");
  }

  async loadData() {
    // Update prices and blockchain data
    await this.priceFetcher.updatePriceDisplay();
    await this.blockchainFetcher.updateBlockDisplay();
  }

  setupRefreshIntervals() {
    // Refresh prices every minute
    setInterval(
      () => this.priceFetcher.updatePriceDisplay(),
      CONFIG.PRICE_REFRESH_INTERVAL
    );

    // Refresh blockchain data every 30 seconds
    setInterval(
      () => this.blockchainFetcher.updateBlockDisplay(),
      CONFIG.BLOCK_REFRESH_INTERVAL
    );
  }

  // Public methods for external use
  updatePrices() {
    return this.priceFetcher.updatePriceDisplay();
  }

  updateBlockData() {
    return this.blockchainFetcher.updateBlockDisplay();
  }

  clearCache() {
    this.cache.clear();
  }
}

// ============================================
// DIGITAL CLOCK
// ============================================
function updateDigitalClock() {
  const now = new Date();
  
  // Format date: DD/MM/YYYY
  const day = String(now.getDate()).padStart(2, '0');
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const year = now.getFullYear();
  const dateString = `${day}/${month}/${year}`;
  
  // Format time: HH:MM:SS
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  const timeString = `${hours}:${minutes}:${seconds}`;
  
  // Update DOM elements
  const dateElement = document.getElementById('clockDate');
  const timeElement = document.getElementById('clockTime');
  
  if (dateElement) dateElement.textContent = dateString;
  if (timeElement) timeElement.textContent = timeString;
}

// ============================================
// WALLET STATUS CHECKER
// ============================================
class WalletStatusChecker {
  constructor() {
    this.apiBase = '/api/v1';
  }

  /**
   * Check if there's a system default wallet configured
   */
  async checkSystemWallet() {
    try {
      const response = await fetch(`${this.apiBase}/wallet/system-default`);
      const data = await response.json();
      
      if (response.ok && data.status === 'success') {
        console.log('System wallet found:', data.wallet_id);
        return {
          hasWallet: true,
          walletId: data.wallet_id,
          metadata: data.metadata
        };
      } else {
        console.log('No system wallet configured');
        return {
          hasWallet: false,
          error: data.error
        };
      }
    } catch (error) {
      console.error('Error checking wallet status:', error);
      return {
        hasWallet: false,
        error: error.message
      };
    }
  }

  /**
   * Check LND wallet status
   */
  async checkLNDStatus() {
    try {
      const response = await fetch(`${this.apiBase}/lnd/info`);
      const data = await response.json();
      
      if (response.ok) {
        return {
          isUnlocked: true,
          nodeInfo: data
        };
      } else {
        return {
          isUnlocked: false,
          error: data.error
        };
      }
    } catch (error) {
      console.error('LND status check failed:', error);
      return {
        isUnlocked: false,
        error: error.message
      };
    }
  }

  /**
   * Initialize wallet on system startup
   */
  async initializeSystemWallet(walletId) {
    try {
      console.log(`Initializing system wallet: ${walletId}`);
      
      // Check if main.html is already handling wallet initialization
      if (window.walletInitializationInProgress) {
        console.log('Wallet initialization already in progress from main.html, skipping...');
        return {
          success: true,
          message: 'Wallet initialization handled by main.html'
        };
      }
      
      // Set flag to prevent duplicate initialization
      window.walletInitializationInProgress = true;
      
      // First try to load the wallet without password (for unencrypted wallets)
      const loadResponse = await fetch(`${this.apiBase}/wallet/load`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          wallet_id: walletId,
          password: ''
        })
      });
      
      const loadData = await loadResponse.json();
      
      if (loadResponse.ok) {
        console.log('System wallet loaded successfully');
        
        // Try to integrate with LND if not already done
        await this.integrateWithLND(walletId);
        
        return {
          success: true,
          message: 'Wallet initialized successfully'
        };
      } else if (loadResponse.status === 401 && loadData.error && loadData.error.includes('Invalid password')) {
        // Wallet is encrypted, use the existing password prompt from main.html
        console.log('Wallet is encrypted, using existing password prompt...');
        
        // Check if window.mainWalletManager exists (from main.html)
        if (window.mainWalletManager && typeof window.mainWalletManager.promptForPassword === 'function') {
          try {
            const password = await window.mainWalletManager.promptForPassword(walletId, 1);
            
            // Try loading with the password
            const retryResponse = await fetch(`${this.apiBase}/wallet/load`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                wallet_id: walletId,
                password: password
              })
            });
            
            const retryData = await retryResponse.json();
            
            if (retryResponse.ok) {
              console.log('System wallet loaded successfully with password');
              await this.integrateWithLND(walletId);
              return {
                success: true,
                message: 'Wallet initialized successfully with password'
              };
            } else {
              return {
                success: false,
                error: retryData.error
              };
            }
          } catch (error) {
            return {
              success: false,
              error: error.message
            };
          }
        } else {
          // If main.html modal not available, just return error - no fallback modal
          console.log('Password prompt not available, wallet is encrypted but main.html not loaded yet');
          return {
            success: false,
            error: 'Wallet is encrypted - please wait for page to fully load'
          };
        }
      } else {
        console.error('Failed to load wallet:', loadData.error);
        return {
          success: false,
          error: loadData.error
        };
      }
    } catch (error) {
      console.error('Wallet initialization failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Integrate wallet with LND
   */
  async integrateWithLND(walletId) {
    try {
      const response = await fetch(`${this.apiBase}/wallet/integrate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          wallet_id: walletId,
          integration_type: 'lnd_auto'
        })
      });
      
      const data = await response.json();
      
      if (response.ok) {
        console.log('LND integration successful');
        return true;
      } else {
        console.log('LND integration skipped or failed:', data.error);
        return false;
      }
    } catch (error) {
      console.log('LND integration error:', error);
      return false;
    }
  }

  /**
   * Redirect to wallet creation page
   */
  redirectToWalletCreation() {
    console.log('Redirecting to wallet creation page...');
    window.location.href = '../components/wallet/wallet.html';
  }

  /**
   * Show wallet status in UI
   */
  showWalletStatus(status) {
    // Create a temporary status indicator
    const statusDiv = document.createElement('div');
    statusDiv.id = 'wallet-status';
    statusDiv.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: ${status.success ? '#28a745' : '#dc3545'};
      color: white;
      padding: 10px 20px;
      border-radius: 5px;
      z-index: 1000;
      font-family: 'Orbitron', monospace;
      font-size: 14px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.3);
    `;
    statusDiv.textContent = status.message || (status.success ? 'Sistema Wallet Ativo' : 'Erro no Sistema Wallet');
    
    document.body.appendChild(statusDiv);
    
    // Remove after 5 seconds
    setTimeout(() => {
      if (statusDiv.parentNode) {
        statusDiv.parentNode.removeChild(statusDiv);
      }
    }, 5000);
  }
}

// ============================================
// INITIALIZE APP ON DOM READY
// ============================================
document.addEventListener("DOMContentLoaded", async () => {
  // Check if we're in an iframe and if parent is handling wallet initialization
  const isInIframe = window !== window.top;
  
  if (isInIframe) {
    // We're in an iframe - let the parent handle wallet initialization
    console.log('Running in iframe - letting parent handle wallet initialization');
    
    // Initialize only the non-wallet parts of the app
    const priceFetcher = new BitcoinPriceFetcher();
    const blockFetcher = new BlockchainDataFetcher();

    // Start periodic updates
    priceFetcher.updatePriceDisplay();
    setInterval(() => priceFetcher.updatePriceDisplay(), CONFIG.PRICE_REFRESH_INTERVAL);
    
    blockFetcher.updateBlockDisplay();
    setInterval(() => blockFetcher.updateBlockDisplay(), CONFIG.BLOCK_REFRESH_INTERVAL);

    // Initialize digital clock
    setInterval(updateDigitalClock, 1000);
    updateDigitalClock();

    console.log('PagCoin Application initialized successfully');
    return;
  }

  // Only initialize wallet system if we're not in an iframe
  // Initialize wallet status checker
  const walletChecker = new WalletStatusChecker();
  
  // Check wallet configuration
  console.log('Checking system wallet configuration...');
  const walletStatus = await walletChecker.checkSystemWallet();
  
  if (walletStatus.hasWallet) {
    // Found a default wallet - initialize it
    console.log(`Found system wallet: ${walletStatus.walletId}`);
    
    // Show loading indicator
    walletChecker.showWalletStatus({
      success: true,
      message: `Inicializando wallet ${walletStatus.walletId}...`
    });
    
    // Initialize the system wallet
    const initResult = await walletChecker.initializeSystemWallet(walletStatus.walletId);
    
    if (initResult.success) {
      walletChecker.showWalletStatus({
        success: true,
        message: 'Sistema wallet ativo'
      });
    } else {
      walletChecker.showWalletStatus({
        success: false,
        message: 'Erro ao inicializar wallet'
      });
      console.error('Wallet initialization failed:', initResult.error);
    }
    
    // Continue with normal app initialization
    updateDigitalClock();
    setInterval(updateDigitalClock, 1000);
    window.pagCoinApp = new PagCoinApp();
    
  } else {
    // No default wallet found - redirect to wallet creation
    console.log('No system wallet configured, redirecting to wallet creation...');
    
    walletChecker.showWalletStatus({
      success: false,
      message: 'Configuração de wallet necessária - redirecionando...'
    });
    
    // Wait a moment for user to see the message, then redirect
    setTimeout(() => {
      walletChecker.redirectToWalletCreation();
    }, 2000);
  }

  // Initialize all other app components for standalone mode
  const priceFetcher = new BitcoinPriceFetcher();
  const blockFetcher = new BlockchainDataFetcher();
  
  priceFetcher.updatePriceDisplay();
  setInterval(() => priceFetcher.updatePriceDisplay(), CONFIG.PRICE_REFRESH_INTERVAL);
  
  blockFetcher.updateBlockDisplay();
  setInterval(() => blockFetcher.updateBlockDisplay(), CONFIG.BLOCK_REFRESH_INTERVAL);
});

// ============================================
// UTILITIES
// ============================================

/**
 * Format number to Brazilian locale
 */
function formatNumberBR(num) {
  return new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(num);
}

/**
 * Debounce function for performance
 */
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Throttle function for performance
 */
function throttle(func, limit) {
  let inThrottle;
  return function (...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}
