// Simulates a host runtime that treats an unhandled rejection as fatal
// (for example Platformatic Watt, or Node.js without Next.js's own listener).
process.on('unhandledRejection', (reason) => {
  console.error('[host] fatal unhandledRejection, exiting:', reason?.message)
  process.exit(1)
})
