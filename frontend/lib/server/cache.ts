type CacheEntry<T> = {
  expiresAt: number;
  value: T;
};

const memoryCache = new Map<string, CacheEntry<unknown>>();

export async function readThroughCache<T>(
  key: string,
  ttlMs: number,
  factory: () => Promise<T>,
): Promise<T> {
  const now = Date.now();
  const hit = memoryCache.get(key) as CacheEntry<T> | undefined;

  if (hit && hit.expiresAt > now) {
    return hit.value;
  }

  const value = await factory();
  memoryCache.set(key, {
    expiresAt: now + ttlMs,
    value,
  });

  return value;
}
