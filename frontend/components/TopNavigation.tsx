"use client";

import { usePrivy } from "@privy-io/react-auth";
import Link from "next/link";
import { useAccount, useSwitchChain } from "wagmi";
import { APP_CONFIG } from "@/config";

function shortAddress(address: string) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function walletButtonLabel(address?: string) {
  return address ? `Connected wallet ${shortAddress(address)}` : "Connect Wallet";
}

function DisabledConnectWalletButton() {
  return (
    <button
      aria-label="Connect Wallet"
      className="rounded-full border border-line px-4 py-2 text-sm font-semibold text-ink-soft opacity-60"
      disabled
      title="Set NEXT_PUBLIC_PRIVY_APP_ID to enable wallet connections."
      type="button"
    >
      Connect Wallet
    </button>
  );
}

export function PrivyConnectWalletButton({ address }: { address?: string }) {
  const { connectWallet, ready } = usePrivy();
  const buttonLabel = walletButtonLabel(address);

  return (
    <button
      aria-label={buttonLabel}
      className="rounded-full bg-brand px-4 py-2 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
      disabled={!ready}
      onClick={() =>
        void connectWallet({
          description: "Connect a wallet on Base to unlock depositor-specific actions.",
          walletList: [...APP_CONFIG.privyWalletList],
        })
      }
      title={buttonLabel}
      type="button"
    >
      {buttonLabel}
    </button>
  );
}

export function TopNavigation() {
  const { address, chainId, isConnected } = useAccount();
  const { switchChain } = useSwitchChain();

  const canViewOperator = address?.toLowerCase() === APP_CONFIG.operatorAddress.toLowerCase();
  const showSwitchToBase = Boolean(isConnected && chainId !== APP_CONFIG.chainId);

  return (
    <header className="mx-auto w-full max-w-[1480px] px-4 pt-4 sm:px-6 lg:px-8">
      <div className="panel subtle-grid flex flex-col gap-4 overflow-hidden px-5 py-5 lg:flex-row lg:items-center lg:justify-between lg:px-7">
        <div className="flex flex-col gap-2">
          <div>
            <p className="text-xs uppercase tracking-[0.28em] text-ink-soft">BOTCOIN Pool Console</p>
            <h1 className="text-2xl font-semibold text-ink sm:text-3xl">Depositor-first live pool interface</h1>
          </div>
          <div className="flex flex-wrap gap-2 text-xs text-ink-muted">
            <Link className="data-chip hover:border-brand hover:text-brand" href="/">
              Dashboard
            </Link>
            <Link className="data-chip hover:border-brand hover:text-brand" href="/history">
              History
            </Link>
            {canViewOperator ? (
              <Link className="data-chip hover:border-brand hover:text-brand" href="/operator">
                Operator Console
              </Link>
            ) : null}
            <span className="data-chip">Pool {shortAddress(APP_CONFIG.defaultPoolAddress)}</span>
          </div>
        </div>
        <div className="flex justify-end">
          {showSwitchToBase ? (
            <button
              aria-label="Switch To Base"
              className="rounded-full bg-brand px-4 py-2 text-sm font-semibold text-surface-soft transition-opacity duration-200 hover:opacity-90"
              onClick={() => switchChain({ chainId: APP_CONFIG.chainId })}
              type="button"
            >
              Switch To Base
            </button>
          ) : APP_CONFIG.privyAppId ? (
            <PrivyConnectWalletButton address={address} />
          ) : (
            <DisabledConnectWalletButton />
          )}
        </div>
      </div>
    </header>
  );
}
