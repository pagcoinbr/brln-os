/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable Turbopack configuration (required for Next.js 16+)
  turbopack: {},

  // Enable standalone output for production deployment
  output: "standalone",

  // Configure allowed development origins for cross-origin requests
  allowedDevOrigins: [
    "100.78.46.97:3001",
    "192.168.68.50:3001",
    "localhost:3001",
    "127.0.0.1:3001",
  ],

  // Image optimization configuration
  images: {
    unoptimized: true, // Since we're serving from a local node
    remotePatterns: [
      {
        protocol: "http",
        hostname: "localhost",
        port: "",
        pathname: "/**",
      },
      {
        protocol: "http",
        hostname: "192.168.68.50",
        port: "",
        pathname: "/**",
      },
      {
        protocol: "http",
        hostname: "100.78.46.97",
        port: "",
        pathname: "/**",
      },
    ],
  },

  // Asset prefix for custom deployment
  assetPrefix: process.env.NODE_ENV === "production" ? "/frontend" : "",

  // Custom headers for security and CORS
  async headers() {
    return [
      {
        source: "/api/:path*",
        headers: [
          { key: "Access-Control-Allow-Origin", value: "*" },
          {
            key: "Access-Control-Allow-Methods",
            value: "GET, POST, PUT, DELETE, OPTIONS",
          },
          {
            key: "Access-Control-Allow-Headers",
            value: "Content-Type, Authorization",
          },
        ],
      },
    ];
  },

  // Rewrites for API compatibility
  async rewrites() {
    return [
      {
        source: "/cgi-bin/:path*",
        destination: "/api/:path*",
      },
    ];
  },

  // Server external packages
  serverExternalPackages: [],
};

export default nextConfig;
