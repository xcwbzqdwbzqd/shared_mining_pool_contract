import { appendFile } from "node:fs/promises";
import path from "node:path";

function resolveLogFilePath() {
  if (process.cwd().endsWith("/frontend")) {
    return path.resolve(process.cwd(), "../shared_mining_pool_contract.log");
  }

  return path.resolve(process.cwd(), "shared_mining_pool_contract.log");
}

export async function writeServerDebug(
  scope: string,
  message: string,
  details: Record<string, unknown> = {},
) {
  const line = `[${new Date().toISOString()}] [frontend] [${scope}] DEBUG ${message} ${JSON.stringify(details)}\n`;

  console.debug(`前端服务端调试 ${scope}: ${message}`, details);

  try {
    await appendFile(resolveLogFilePath(), line, "utf8");
  } catch (error) {
    console.debug("前端服务端日志写入失败", error);
  }
}
