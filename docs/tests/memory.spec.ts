import { describe, expect, it } from 'vitest'
import { type Memory, memoryOf } from '@/memory'

describe('the memory of a behaviour', (): void => {
  it('reads the initial state for an owner nothing was written for', (): void => {
    const memory: Memory<object, number> = memoryOf<object, number>(7)
    expect(memory.read({})).toBe(7)
  })

  it('keeps what was written for each owner apart', (): void => {
    const memory: Memory<object, string> = memoryOf<object, string>('initial')
    const first: object = {}
    const second: object = {}
    memory.write(first, 'first')
    expect([memory.read(first), memory.read(second)]).toEqual(['first', 'initial'])
  })
})
