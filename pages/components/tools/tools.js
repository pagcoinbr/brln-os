// ============================================
// FERRAMENTAS - CONVERSOR E CALCULADORA P2P
// ============================================

// Abrir aplicativo na mesma página usando proxy reverso
function abrirApp(porta) {
  const proxyPaths = {
    8889: '/lndg/',
    3000: '/thunderhub/',
    5000: '/lnbits/',
    35671: '/simple-lnwallet/',
    1984: '/peerswap/'
  };
  
  const url = proxyPaths[porta] || `http://${window.location.hostname}:${porta}`;
  window.location.href = url;
}

document.addEventListener("DOMContentLoaded", () => {
  // ===== CONVERSOR =====
  // Mapeamento dos elementos do conversor
  const converterInputs = {
    brl: document.getElementById("inputBRL"),
    usd: document.getElementById("inputUSD"),
    eur: document.getElementById("inputEUR"),
    btc: document.getElementById("inputBTC"),
    sats: document.getElementById("inputSATS"),
  };

  const converterDisplays = {
    btc_brl: document.getElementById("btcToReais"),
    usd_brl: document.getElementById("usdToReais"),
    eur_brl: document.getElementById("eurToReais"),
  };

  // ===== CALCULADORA P2P =====
  const p2pInputBRL = document.getElementById("clientValueBRL");
  const p2pInputUSD = document.getElementById("clientValueUSD");
  const p2pInputAgio = document.getElementById("markupPercentage");
  const p2pOutputSats = document.getElementById("p2pResult");
  const p2pQuoteBTC = document.getElementById("quoteBTC");
  const p2pQuoteUSD = document.getElementById("quoteUSD");
  const p2pGrossValue = document.getElementById("grossValue");
  const p2pMarkupValue = document.getElementById("markupValue");
  const p2pTotalWithMarkup = document.getElementById("totalWithMarkup");
  const p2pTotalBTC = document.getElementById("totalBTC");

  // Objeto para armazenar as cotações da API
  let rates = {
    btc_in_brl: 0,
    btc_in_usd: 0,
    btc_in_eur: 0,
    usd_in_brl: 0,
    eur_in_brl: 0,
  };

  // Flag para evitar loops de atualização no conversor
  let isUpdating = false;

  /**
   * Busca as cotações mais recentes na API da CoinGecko.
   * Se falhar, tenta a API da CoinMarketCap como fallback.
   */
  async function fetchRates() {
    try {
      const response = await fetch(
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=brl,usd,eur"
      );
      if (!response.ok)
        throw new Error("A resposta da API não foi bem-sucedida.");

      const data = await response.json();
      rates.btc_in_brl = data.bitcoin.brl;
      rates.btc_in_usd = data.bitcoin.usd;
      rates.btc_in_eur = data.bitcoin.eur;
      rates.usd_in_brl = rates.btc_in_brl / rates.btc_in_usd;
      rates.eur_in_brl = rates.btc_in_brl / rates.btc_in_eur;

      updateDisplays();
    } catch (error) {
      console.error("Erro ao buscar cotações da CoinGecko:", error);
      console.log("Tentando fallback com CoinMarketCap...");
      
      // Fallback: tenta a API da CoinMarketCap
      try {
        const cmcResponse = await fetch(
          "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?symbol=BTC&convert=BRL,USD,EUR",
          {
            headers: {
              "X-CMC_PRO_API_KEY": "956ac128-f7ee-4f55-9ad3-2de66c7851b3"
            }
          }
        );
        
        if (!cmcResponse.ok)
          throw new Error("Falha na API da CoinMarketCap.");
        
        const cmcData = await cmcResponse.json();
        const btcData = cmcData.data.BTC;
        
        rates.btc_in_brl = btcData.quote.BRL.price;
        rates.btc_in_usd = btcData.quote.USD.price;
        rates.btc_in_eur = btcData.quote.EUR.price;
        rates.usd_in_brl = rates.btc_in_brl / rates.btc_in_usd;
        rates.eur_in_brl = rates.btc_in_brl / rates.btc_in_eur;

        updateDisplays();
      } catch (fallbackError) {
        console.error("Erro ao buscar cotações da CoinMarketCap:", fallbackError);
        converterDisplays.btc_brl.textContent = "Erro de conexão";
        converterDisplays.usd_brl.textContent = "Erro de conexão";
        p2pQuoteBTC.textContent = "Indisponível";
      }
    }
  }

  /**
   * Atualiza os displays com as cotações atuais
   */
  function updateDisplays() {
    // Atualiza os displays do conversor
    converterDisplays.btc_brl.textContent = `R$ ${rates.btc_in_brl.toLocaleString(
      "pt-BR",
      { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    )}`;
    converterDisplays.usd_brl.textContent = `R$ ${rates.usd_in_brl.toLocaleString(
      "pt-BR",
      { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    )}`;
    converterDisplays.eur_brl.textContent = `R$ ${rates.eur_in_brl.toLocaleString(
      "pt-BR",
      { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    )}`;

    // Atualiza o display da calculadora P2P
    p2pQuoteBTC.textContent = rates.btc_in_brl.toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
    p2pQuoteUSD.textContent = rates.btc_in_usd.toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    // Recalcula a calculadora P2P após atualizar as cotações
    calcularP2P();
  }

  /**
   * Calcula e atualiza todos os campos do conversor com base no campo que foi alterado.
   * @param {string} source - A chave do campo que originou a mudança (ex: 'brl', 'usd').
   */
  function calculateConverterValues(source) {
    // Previne execuções desnecessárias ou em loop
    if (isUpdating || rates.btc_in_brl === 0) return;
    isUpdating = true;

    const sourceValue = parseFloat(converterInputs[source].value);

    // Se o campo estiver vazio ou for inválido, limpa os outros
    if (isNaN(sourceValue) || sourceValue === 0) {
      for (const key in converterInputs) {
        if (key !== source) {
          converterInputs[key].value = "";
        }
      }
      isUpdating = false;
      return;
    }

    let btcValue = 0;
    // Converte o valor de entrada para um valor base em BTC
    switch (source) {
      case "brl":
        btcValue = sourceValue / rates.btc_in_brl;
        break;
      case "usd":
        btcValue = sourceValue / rates.btc_in_usd;
        break;
      case "eur":
        btcValue = sourceValue / rates.btc_in_eur;
        break;
      case "btc":
        btcValue = sourceValue;
        break;
      case "sats":
        btcValue = sourceValue / 100_000_000;
        break;
    }

    // Atualiza todos os outros campos com base no valor em BTC
    if (source !== "brl") {
      converterInputs.brl.value = (btcValue * rates.btc_in_brl).toFixed(2);
    }
    if (source !== "usd") {
      converterInputs.usd.value = (btcValue * rates.btc_in_usd).toFixed(2);
    }
    if (source !== "eur") {
      converterInputs.eur.value = (btcValue * rates.btc_in_eur).toFixed(2);
    }
    if (source !== "btc") {
      converterInputs.btc.value = btcValue.toFixed(8);
    }
    if (source !== "sats") {
      // Arredonda os satoshis para o inteiro mais próximo
      converterInputs.sats.value = Math.round(btcValue * 100_000_000);
    }

    isUpdating = false;
  }

  /**
   * Calcula os satoshis com ágio para a calculadora P2P
   */
  let isP2PUpdating = false;

  function calcularP2P(source = "brl") {
    if (isP2PUpdating) return;
    isP2PUpdating = true;

    const brl = parseFloat(p2pInputBRL.value) || 0;
    const usd = parseFloat(p2pInputUSD.value) || 0;
    let agio = -Math.abs(parseFloat(p2pInputAgio.value) || 0);

    // Se nenhum valor foi fornecido, limpa os resultados
    if ((brl <= 0 && usd <= 0) || rates.btc_in_brl === 0) {
      p2pOutputSats.textContent = "0";
      p2pGrossValue.textContent = "0 BTC";
      p2pMarkupValue.textContent = "R$ 0,00";
      p2pTotalWithMarkup.textContent = "R$ 0,00";
      p2pTotalBTC.textContent = "0 BTC";
      isP2PUpdating = false;
      return;
    }

    let btcValue = 0;
    let valueBRL = 0;

    // Calcula com base na fonte (BRL ou USD)
    if (source === "brl" && brl > 0) {
      valueBRL = brl;
      btcValue = brl / rates.btc_in_brl;
      // Atualiza USD baseado em BRL
      p2pInputUSD.value = (brl / rates.usd_in_brl).toFixed(2);
    } else if (source === "usd" && usd > 0) {
      valueBRL = usd * rates.usd_in_brl;
      btcValue = usd / rates.btc_in_usd;
      // Atualiza BRL baseado em USD
      p2pInputBRL.value = valueBRL.toFixed(2);
    } else {
      isP2PUpdating = false;
      return;
    }

    const btcWithAgio = btcValue * (1 + agio / 100);
    const satsResult = Math.floor(btcWithAgio * 100_000_000);
    const markupValueBRL = valueBRL * (agio / 100);
    const totalWithMarkupBRL = valueBRL + markupValueBRL;

    p2pOutputSats.textContent = satsResult.toLocaleString("pt-BR");
    p2pGrossValue.textContent = btcValue.toFixed(8) + " BTC";
    p2pMarkupValue.textContent =
      "R$ " +
      markupValueBRL.toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    p2pTotalWithMarkup.textContent =
      "R$ " +
      totalWithMarkupBRL.toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    p2pTotalBTC.textContent = btcWithAgio.toFixed(8) + " BTC";

    isP2PUpdating = false;
  }

  // Adiciona "ouvintes" de eventos para cada campo de input do conversor
  for (const key in converterInputs) {
    converterInputs[key].addEventListener("input", () =>
      calculateConverterValues(key)
    );
  }

  // Adiciona "ouvintes" de eventos para os campos da calculadora P2P
  p2pInputBRL.addEventListener("input", () => calcularP2P("brl"));
  p2pInputUSD.addEventListener("input", () => calcularP2P("usd"));
  p2pInputAgio.addEventListener("input", () => {
    const source = parseFloat(p2pInputBRL.value) > 0 ? "brl" : "usd";
    calcularP2P(source);
  });

  // Busca as cotações assim que a página carrega
  fetchRates();
  // E define um intervalo para atualizar as cotações a cada 60 segundos
  setInterval(fetchRates, 60000);
});
