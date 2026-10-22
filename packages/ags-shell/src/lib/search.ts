function normalize(text: string): string {
  return text.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase();
}

function tokenScore(text: string, token: string): number | null {
  if (text === token) return 0;

  const contiguous = text.indexOf(token);
  if (contiguous >= 0) return 1 + contiguous / (text.length + 1);

  let cursor = 0;
  let first = -1;
  let last = -1;
  for (const character of token) {
    const position = text.indexOf(character, cursor);
    if (position < 0) return null;
    if (first < 0) first = position;
    last = position;
    cursor = position + character.length;
  }

  const gaps = last - first + 1 - token.length;
  return 2 + (gaps + first / (text.length + 1)) / (text.length + 1);
}

// Every query word must match. Lower scores prefer contiguous, earlier matches.
export function fuzzyRank<T>(
  items: readonly T[],
  query: string,
  textOf: (item: T) => string,
): T[] {
  const tokens = normalize(query).trim().split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return [...items];

  return items
    .map((item, index) => {
      const text = normalize(textOf(item));
      let score = 0;
      for (const token of tokens) {
        const value = tokenScore(text, token);
        if (value === null) return null;
        score += value;
      }
      return { item, index, score };
    })
    .filter((match) => match !== null)
    .sort((a, b) => a.score - b.score || a.index - b.index)
    .map((match) => match.item);
}
