import { describe, expect, it } from 'vitest'
import { cleanContact, validateContact } from './contactValidation.js'

const good = {
  name: 'Sam Sender',
  email: 'sam@gmail.com',
  message: 'When is practice?',
}

describe('validateContact', () => {
  it('accepts a complete, valid message (any email provider)', () => {
    expect(validateContact(good)).toEqual({})
  })

  it('needs a name', () => {
    expect(validateContact({ ...good, name: '  ' }).name).toBeTruthy()
  })

  it('rejects obviously wrong emails', () => {
    for (const email of [
      '',
      'sam',
      'sam@',
      'sam@gmail',
      'sam @gmail.com',
      '@gmail.com',
    ]) {
      expect(validateContact({ ...good, email }).email).toBeTruthy()
    }
  })

  it('needs a message of 1 to 2000 characters after trimming', () => {
    expect(validateContact({ ...good, message: '   ' }).message).toBeTruthy()
    expect(validateContact({ ...good, message: 'a'.repeat(2000) })).toEqual({})
    expect(
      validateContact({ ...good, message: 'a'.repeat(2001) }).message,
    ).toBeTruthy()
  })
})

describe('cleanContact', () => {
  it('trims all three fields', () => {
    expect(
      cleanContact({
        name: ' Sam ',
        email: ' sam@gmail.com ',
        message: ' Hi \n',
      }),
    ).toEqual({
      name: 'Sam',
      email: 'sam@gmail.com',
      message: 'Hi',
    })
  })
})
