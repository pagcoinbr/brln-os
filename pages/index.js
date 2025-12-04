import database from "../infra/database.js";

function home() {
  return <h1>Welcome to the Home Page</h1>;
}

function status(request, response) {
  response.status(200).json({ status: "OK" });
}

export default status;
