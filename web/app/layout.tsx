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
  title: "Hermes",
  description: "A discrete meeting recorder for macOS.",
  metadataBase: new URL("https://hermes.viraat.dev"),
  icons: {
    icon: [{ url: "/favicon.svg", type: "image/svg+xml" }],
    shortcut: ["/favicon.svg"],
    apple: ["/apple-icon.png"],
  },
  openGraph: {
    title: "Hermes",
    description: "A discrete meeting recorder for macOS.",
    type: "website",
    images: [{ url: "/opengraph-image.png?v=3", width: 1200, height: 1200, alt: "Hermes" }],
  },
  twitter: {
    card: "summary",
    title: "Hermes",
    description: "A discrete meeting recorder for macOS.",
    images: ["/twitter-image.png?v=3"],
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
