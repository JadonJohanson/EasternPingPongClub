import { describe, expect, it } from 'vitest'
import { filterPlayers, normalize } from './search.js'

const players = [
  { id: '1', display_name: 'Blake Chen' },
  { id: '2', display_name: 'José Álvarez' },
  { id: '3', display_name: "Sam O'Connor" },
]

describe('normalize', () => {
  it('ignores case, accents and extra spaces', () => {
    expect(normalize('  JOSÉ   Álvarez ')).toBe('jose alvarez')
  })
})

describe('filterPlayers', () => {
  it('returns everyone for an empty search', () => {
    expect(filterPlayers(players, '   ')).toHaveLength(3)
  })

  it('matches part of a name, ignoring case and accents', () => {
    expect(filterPlayers(players, 'jose').map((p) => p.id)).toEqual(['2'])
  })

  it('matches words in any order', () => {
    expect(filterPlayers(players, 'chen bl').map((p) => p.id)).toEqual(['1'])
  })

  it('returns nothing when no name matches', () => {
    expect(filterPlayers(players, 'zzz')).toEqual([])
  })
})
