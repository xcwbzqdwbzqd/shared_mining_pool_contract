import type { Metadata } from "next";
import { IBM_Plex_Sans, Space_Grotesk } from "next/font/google";
import { Providers } from "./providers";
import { TopNavigation } from "@/components/TopNavigation";
import "./globals.css";

const headingFont = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-heading",
});

const bodyFont = IBM_Plex_Sans({
  subsets: ["latin"],
  variable: "--font-body",
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "BOTCOIN Pool Console",
  description:
    "Depositor-first control surface for the live BOTCOIN shared mining pool on Base mainnet.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${headingFont.variable} ${bodyFont.variable} bg-canvas text-ink`}>
        <Providers>
          <TopNavigation />
          <main className="mx-auto flex min-h-screen w-full max-w-[1480px] flex-col px-4 pb-16 pt-6 sm:px-6 lg:px-8">
            {children}
          </main>
        </Providers>
      </body>
    </html>
  );
}
