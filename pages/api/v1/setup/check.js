import fs from "fs";
import path from "path";

export default function handler(request, response) {
  try {
    const dataPath = "/data";
    const exists = fs.existsSync(dataPath);

    response.status(200).json({
      setupComplete: exists,
      dataPath: dataPath,
    });
  } catch (error) {
    response.status(500).json({
      error: "Erro ao verificar diretório de dados",
      message: error.message,
    });
  }
}
