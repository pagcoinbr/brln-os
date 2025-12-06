import fs from "fs";
import path from "path";

export default function handler(request, response) {
  if (request.method !== "POST") {
    return response.status(405).json({ error: "Method not allowed, try POST" });
  }

  try {
    const dataPath = "/data";

    // Verifica se o diretório já existe
    if (!fs.existsSync(dataPath)) {
      fs.mkdirSync(dataPath, { recursive: true });
    }

    // Você pode adicionar mais passos de inicialização aqui
    // Por exemplo, criar arquivos de configuração, banco de dados, etc.

    response.status(200).json({
      success: true,
      message: "Sistema inicializado com sucesso",
      dataPath: dataPath,
    });
  } catch (error) {
    response.status(500).json({
      success: false,
      error: "Erro ao inicializar sistema",
      message: error.message,
    });
  }
}
