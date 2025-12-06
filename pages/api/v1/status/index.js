import database from "../../../../infra/database.js";

async function status (request, response) {
  const result = await database.query(SELECT 1 + 1)
  response.status(200).json({ status: "Connected" });
};

export default status;