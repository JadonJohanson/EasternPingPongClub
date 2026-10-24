import { describe, expect, it } from 'vitest'
import {
  buildMatch,
  isValidGame,
  parseScore,
  tally,
  validateMatch,
} from './matchValidation.js'

const player = (id) => ({ playerId: id, guestName: '' })
const guest = (name) => ({ playerId: '', guestName: name })
const good = {
  a: player('p1'),
  b: player('p2'),
  pointsTo: 11,
  winByTwo: true,
  games: [
    { a: '11', b: '7' },
    { a: '9', b: '11' },
    { a: '11', b: '8' },
  ],
}

describe('isValidGame', () => {
  it('accepts normal and deuce scores (win by 2)', () => {
    expect(isValidGame(11, 9, 11, true)).toBe(true)
    expect(isValidGame(0, 11, 11, true)).toBe(true)
    expect(isValidGame(12, 10, 11, true)).toBe(true)
    expect(isValidGame(23, 21, 21, true)).toBe(true)
  })
  it('rejects unfinished or impossible scores (win by 2)', () => {
    expect(isValidGame(11, 10, 11, true)).toBe(false)
    expect(isValidGame(10, 8, 11, true)).toBe(false)
    expect(isValidGame(13, 10, 11, true)).toBe(false)
    expect(isValidGame(11, 11, 11, true)).toBe(false)
  })
  it('without win by 2, first to the target wins outright', () => {
    expect(isValidGame(11, 10, 11, false)).toBe(true)
    expect(isValidGame(12, 10, 11, false)).toBe(false)
  })
  it('rejects non-whole numbers and out-of-range values', () => {
    expect(isValidGame(null, 5, 11, true)).toBe(false)
    expect(isValidGame(100, 98, 11, true)).toBe(false)
  })
})

describe('parseScore', () => {
  it('reads whole numbers only', () => {
    expect(parseScore(' 9')).toBe(9)
    expect(parseScore('')).toBeNull()
    expect(parseScore('1.5')).toBeNull()
    expect(parseScore('-1')).toBeNull()
  })
})

describe('tally', () => {
  it('counts games won by each side', () => {
    expect(tally(good.games, 11, true)).toEqual({ winsA: 2, winsB: 1 })
  })
})

describe('validateMatch', () => {
  it('accepts a good match, with or without a guest', () => {
    expect(validateMatch(good)).toEqual({})
    expect(validateMatch({ ...good, b: guest('Visitor') })).toEqual({})
  })
  it('needs a player or guest on each side', () => {
    expect(validateMatch({ ...good, a: guest('  ') }).a).toBeDefined()
  })
  it('rejects the same player on both sides', () => {
    expect(validateMatch({ ...good, b: player('p1') }).b).toContain(
      'themselves',
    )
  })
  it('rejects guest vs guest', () => {
    expect(
      validateMatch({ ...good, a: guest('X'), b: guest('Y') }).b,
    ).toBeDefined()
  })
  it('rejects a player and a guest name on the same side', () => {
    expect(
      validateMatch({ ...good, a: { playerId: 'p1', guestName: 'X' } }).a,
    ).toBeDefined()
  })
  it('needs games, valid scores and a winner', () => {
    expect(
      validateMatch({ ...good, games: [{ a: '', b: '' }] }).games,
    ).toBeDefined()
    expect(
      validateMatch({ ...good, games: [{ a: '11', b: '10' }] }).games,
    ).toContain('Game 1')
    expect(
      validateMatch({
        ...good,
        games: [
          { a: '11', b: '5' },
          { a: '5', b: '11' },
        ],
      }).games,
    ).toContain('tied')
  })
  it('ignores blank game rows', () => {
    expect(
      validateMatch({ ...good, games: [...good.games, { a: '', b: '' }] }),
    ).toEqual({})
  })
})

describe('buildMatch', () => {
  it('builds a casual match with numbered games and no guest for players', () => {
    const { match, games } = buildMatch({ ...good, b: guest(' Visitor ') })
    expect(match).toMatchObject({
      match_type: 'casual',
      player_a_id: 'p1',
      guest_a_name: null,
      player_b_id: null,
      guest_b_name: 'Visitor',
      points_to: 11,
      win_by_two: true,
    })
    expect(games.map((g) => g.game_number)).toEqual([1, 2, 3])
    expect(games[1]).toMatchObject({ score_a: 9, score_b: 11 })
  })
})
