export default {
  testEnvironment: "node",
  testEnvironmentOptions: {
    url: "http://localhost",
  },
  testMatch: ["**/tests/**/*.test.js"],
  collectCoverage: false,
  verbose: true,
  transform: {},
  globals: {
    "ts-jest": {
      isolatedModules: true,
    },
  },
};
