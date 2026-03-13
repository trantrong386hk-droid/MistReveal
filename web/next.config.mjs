/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**.supabase.co",
      },
      {
        protocol: "https",
        hostname: "**.supabase.in",
      },
      {
        protocol: "https",
        hostname: "p16-bot-sign.byteimg.com",
      },
      {
        protocol: "https",
        hostname: "p9-bot-sign.byteimg.com",
      },
      {
        protocol: "https",
        hostname: "*.byteimg.com",
      },
    ],
  },
};

export default nextConfig;
