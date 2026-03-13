import { APP_CONFIG } from "@/config";
import type { StepAvailability } from "@/lib/types";

export function parseEpochListInput(value: string) {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => Number(item))
    .filter((item) => Number.isFinite(item) && item >= 0)
    .sort((left, right) => left - right);
}

export function validateEpochList(value: string): StepAvailability {
  const epochs = parseEpochListInput(value);

  if (epochs.length === 0) {
    return {
      available: false,
      reason: "Enter at least one ended epoch number.",
    };
  }

  if (epochs.length > APP_CONFIG.maxEpochsPerClaim) {
    return {
      available: false,
      reason: `You can submit at most ${APP_CONFIG.maxEpochsPerClaim} epochs per claim call.`,
    };
  }

  for (let index = 1; index < epochs.length; index += 1) {
    if (epochs[index] <= epochs[index - 1]) {
      return {
        available: false,
        reason: "Epoch numbers must be strictly increasing.",
      };
    }
  }

  return {
    available: true,
    reason: "Epoch list is valid.",
  };
}

export function validatePositiveTokenAmount(rawAmount: string): StepAvailability {
  if (!rawAmount.trim()) {
    return {
      available: false,
      reason: "Enter a BOTCOIN amount first.",
    };
  }

  const parsed = Number(rawAmount);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return {
      available: false,
      reason: "Use a positive BOTCOIN amount.",
    };
  }

  return {
    available: true,
    reason: "Amount looks valid.",
  };
}

export function validateMiningCalldata(value: string): StepAvailability {
  const trimmed = value.trim().toLowerCase();

  if (!trimmed.startsWith("0x")) {
    return {
      available: false,
      reason: "Calldata must be a 0x-prefixed hex string.",
    };
  }

  if (trimmed.length < 10) {
    return {
      available: false,
      reason: "Calldata must include at least a 4-byte selector.",
    };
  }

  if (!/^0x[0-9a-f]+$/i.test(trimmed)) {
    return {
      available: false,
      reason: "Calldata contains non-hexadecimal characters.",
    };
  }

  if (!trimmed.startsWith(APP_CONFIG.receiptSubmitSelector)) {
    return {
      available: false,
      reason: `The selector must start with ${APP_CONFIG.receiptSubmitSelector}.`,
    };
  }

  return {
    available: true,
    reason: "Calldata shape matches the allowed receipt selector.",
  };
}
