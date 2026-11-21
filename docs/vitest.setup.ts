import tocbot from 'tocbot'

// The published documents load tocbot from a CDN before the footer script, which reads it as a global. The
// specs that run the whole footer script get the same global, from the real tocbot release.
Object.defineProperty(globalThis, 'tocbot', { value: tocbot, configurable: true, writable: true })
