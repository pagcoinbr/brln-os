import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "BRLN Open Bank",
  description: "Bitcoin Lightning Node Management Interface",
  icons: {
    icon: "/images/logopreto.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className="antialiased">{children}</body>
    </html>
  );
}
