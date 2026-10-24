// Makes text easy to compare: lower case, no accents, no extra spaces.
// "José  Álvarez" and "jose alvarez" then count as the same.
export function normalize(text) {
  return text
    .normalize('NFD') // split "é" into "e" + an accent mark
    .replace(/[̀-ͯ]/g, '') // drop the accent marks
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim()
}

// Keeps the players whose name contains every word typed in the search box,
// in any order ("chen bl" finds "Blake Chen"). An empty search keeps everyone.
export function filterPlayers(players, query) {
  const words = normalize(query).split(' ').filter(Boolean)
  if (words.length === 0) return players
  return players.filter((player) => {
    const name = normalize(player.display_name)
    return words.every((word) => name.includes(word))
  })
}
