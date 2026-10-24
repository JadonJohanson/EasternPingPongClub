import { describe, expect, it } from 'vitest'
import { cleanSignup, validateSignup } from './signupValidation.js'

const good = {
  name: 'Pat Player',
  email: 'pat@my.easternct.edu',
  easternId: '01234567',
  skillLevel: 'intermediate',
}

describe('validateSignup', () => {
  it('accepts a complete, valid form', () => {
    expect(validateSignup(good)).toEqual({})
  })

  it('accepts both school email styles in any letter case', () => {
    expect(validateSignup({ ...good, email: 'pat@easternct.edu' })).toEqual({})
    expect(validateSignup({ ...good, email: 'PAT@MY.EASTERNCT.EDU' })).toEqual(
      {},
    )
  })

  it('rejects non-school and look-alike emails', () => {
    expect(
      validateSignup({ ...good, email: 'pat@gmail.com' }).email,
    ).toBeTruthy()
    expect(
      validateSignup({ ...good, email: 'pat@evil-easternct.edu' }).email,
    ).toBeTruthy()
    expect(
      validateSignup({ ...good, email: 'pat@my.easternct.edu.evil.com' }).email,
    ).toBeTruthy()
  })

  it('needs an Eastern ID of exactly 8 digits', () => {
    expect(
      validateSignup({ ...good, easternId: '1234567' }).easternId,
    ).toBeTruthy()
    expect(
      validateSignup({ ...good, easternId: '123456789' }).easternId,
    ).toBeTruthy()
    expect(
      validateSignup({ ...good, easternId: '1234abcd' }).easternId,
    ).toBeTruthy()
    expect(validateSignup({ ...good, easternId: ' 01234567 ' })).toEqual({})
  })

  it('needs a name and a known skill level', () => {
    expect(validateSignup({ ...good, name: '   ' }).name).toBeTruthy()
    expect(validateSignup({ ...good, skillLevel: '' }).skillLevel).toBeTruthy()
    expect(
      validateSignup({ ...good, skillLevel: 'pro' }).skillLevel,
    ).toBeTruthy()
  })
})

describe('cleanSignup', () => {
  it('trims spaces and uses the database column names', () => {
    expect(
      cleanSignup({
        ...good,
        name: '  Pat Player ',
        email: ' pat@my.easternct.edu ',
      }),
    ).toEqual({
      name: 'Pat Player',
      email: 'pat@my.easternct.edu',
      eastern_id: '01234567',
      skill_level: 'intermediate',
    })
  })
})
