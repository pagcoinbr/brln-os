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
      }
    });
  
    apps.forEach(app => {
      const url = `http://${ip}:${app.porta}`;
      const checkService = () => {
        fetch(url, { method: 'HEAD', mode: 'no-cors' })
          .then(() => {
            const botao = document.getElementById(app.id);
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
  
function salvarPagina(pagina) {
  localStorage.setItem('ultimaPaginaMainFrame', pagina);
}

  document.addEventListener('DOMContentLoaded', () => {
    const temaSalvo = localStorage.getItem('temaAtual') || 'dark';
    document.body.classList.add(`${temaSalvo}-theme`);
    setTimeout(verificarServicosPrincipais, 1000);
  });
  