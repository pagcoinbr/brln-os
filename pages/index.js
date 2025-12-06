import database from "../infra/database.js";
import fs from "fs";

export default function home(request, response) {
  const dataPath = "/data";

  // Verifica se o diretório /data existe
  if (!fs.existsSync(dataPath)) {
    // Se não existir, redireciona para instalação
    response.statusCode = 302;
    response.setHeader("Location", "/install");
    console.log(
      "Diretório /data não encontrado. Redirecionando para instalação do sistema..."
    );
    response.end();
    return;
  } else {
    // Se existir, carrega a página principal
    response.statusCode = 200;
    response.setHeader("Content-Type", "text/html");
    response.end("<h1>Bem-vindo à página principal do sistema!</h1>");
  }
}
