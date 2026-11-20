/** @type {import('next').NextConfig} */
module.exports = {
  output: 'standalone',
  images: {
    unoptimized: true,
    // Workaround: set WORKAROUND=1 at build time to disable the image disk cache.
    ...(process.env.WORKAROUND === '1' && { maximumDiskCacheSize: 0 }),
  },
}
