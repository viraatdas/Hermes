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
  title: "Hermes - Meeting notes for the age of agents",
  description: "Record, transcribe, and save meetings as local markdown files. Your notes stay on your machine, readable by any agent or tool. Open source macOS app.",
  metadataBase: new URL("https://hermes.viraat.dev"),
  icons: {
    icon: [{ url: "/favicon.svg", type: "image/svg+xml" }],
    shortcut: ["/favicon.svg"],
    apple: ["/apple-icon.png"],
  },
  openGraph: {
    title: "Hermes - Meeting notes for the age of agents",
    description: "Record, transcribe, and save meetings as local markdown files. Your notes stay on your machine, readable by any agent or tool.",
    type: "website",
    images: [{ url: "/og-image.png", width: 1200, height: 1200, alt: "Hermes" }],
  },
  twitter: {
    card: "summary",
    title: "Hermes - Meeting notes for the age of agents",
    description: "Record, transcribe, and save meetings as local markdown files. Your notes stay on your machine, readable by any agent or tool.",
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
