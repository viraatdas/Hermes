import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Hermes - The meeting recorder built for agents",
  description: "Record and transcribe meetings to local markdown files. Built-in MCP server gives Claude, Cursor, and any AI tool direct access to your notes. Open source macOS app.",
  metadataBase: new URL("https://hermes.viraat.dev"),
  icons: {
    icon: [{ url: "/favicon.svg", type: "image/svg+xml" }],
    shortcut: ["/favicon.svg"],
    apple: ["/apple-icon.png"],
  },
  openGraph: {
    title: "Hermes - The meeting recorder built for agents",
    description: "Record and transcribe meetings to local markdown files. Built-in MCP server gives Claude, Cursor, and any AI tool direct access to your notes.",
    type: "website",
    images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "Hermes - The meeting recorder built for agents" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Hermes - The meeting recorder built for agents",
    description: "Record and transcribe meetings to local markdown files. Built-in MCP server gives Claude, Cursor, and any AI tool direct access to your notes.",
    images: ["/tw-image.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        {children}
      </body>
    </html>
  );
}
