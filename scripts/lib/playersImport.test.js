import { describe, expect, it } from 'vitest'
import { parseCsv, prepareImport, toSql } from './playersImport.js'

const header = 'name,email,eastern_id,skill_level'

describe('parseCsv', () => {
  it('reads rows by header name, ignoring header case and extra spaces', () => {
    const rows = parseCsv(
      `Name, Email ,eastern_id,Skill_Level\nPat,pat@my.easternct.edu,01234567,Beginner\n`,
    )
    expect(rows).toEqual([
      {
        name: 'Pat',
        email: 'pat@my.easternct.edu',
        eastern_id: '01234567',
        skill_level: 'Beginner',
      },
    ])
  })

  it('handles quotes, commas inside quotes, CRLF line endings and the Excel marker', () => {
    const rows = parseCsv(
      `\uFEFF${header}\r\n"Smith, Sam",s@my.easternct.edu,11112222,advanced\r\n"Say ""hi""",t@my.easternct.edu,11112223,expert`,
    )
    expect(rows.map((r) => r.name)).toEqual(['Smith, Sam', 'Say "hi"'])
  })

  it('skips blank lines', () => {
    expect(
      parseCsv(`${header}\n\nPat,p@my.easternct.edu,11112222,master\n\n`),
    ).toHaveLength(1)
  })
})

describe('prepareImport', () => {
  const good = {
    name: 'Pat Player',
    email: 'pat@my.easternct.edu',
    eastern_id: '01234567',
    skill_level: 'beginner',
  }

  it('accepts good rows', () => {
    expect(prepareImport([good])).toEqual({
      names: ['Pat Player'],
      problems: [],
    })
  })

  it('reports problems with the line number (line 1 is the header)', () => {
    const result = prepareImport([
      good,
      { ...good, name: 'Bad Id', eastern_id: '123' },
    ])
    expect(result.names).toEqual(['Pat Player'])
    expect(result.problems).toHaveLength(1)
    expect(result.problems[0].line).toBe(3)
  })

  it('skips repeated names, ignoring upper/lower case', () => {
    const result = prepareImport([
      good,
      { ...good, name: 'pat player', eastern_id: '99999999' },
    ])
    expect(result.names).toEqual(['Pat Player'])
    expect(result.problems[0].message).toContain('more than once')
  })

  it('rejects names over 80 characters', () => {
    expect(
      prepareImport([{ ...good, name: 'x'.repeat(81) }]).problems,
    ).toHaveLength(1)
  })
})

describe('toSql', () => {
  it("doubles single quotes so names like O'Connor are safe", () => {
    expect(toSql(["Sam O'Connor"])).toContain("('Sam O''Connor')")
  })

  it('skips people who already exist, so it can be run twice', () => {
    expect(toSql(['Pat'])).toContain('where not exists')
  })

  it('says so when there is nothing to add', () => {
    expect(toSql([])).toContain('Nothing to add')
  })
})
