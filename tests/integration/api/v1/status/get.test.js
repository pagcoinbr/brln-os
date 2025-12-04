test("Get to api/v1/status returns 200", async () => {
  const response = await fetch("http://localhost:3000/api/v1/status");
  console.log(await response.json());
  expect(response.status).toBe(200);
});
