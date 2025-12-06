import { client } from "pg";

async function query() {
  const client = new Client();
  await client.connect();
  const result = client.query(queryObject);
  await client.end();
  return result;
}

export default {
  query: query,
};
