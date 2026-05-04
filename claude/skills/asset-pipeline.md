---
name: asset-pipeline
description: Convert, optimize, and upload image/video assets to Cloudflare R2 for wander.com. Use when the user asks to process Figma exports, convert images to WebP, optimize videos, upload assets to R2/CDN, or generate srcSet strings for responsive images.
---

# Asset Pipeline - Figma Export to Cloudflare R2

## Overview

Wander assets are served from `https://assets.wander.com/p/` backed by Cloudflare R2. The workflow is: export from Figma at multiple scales, convert to WebP, upload to R2, reference in code with responsive `srcSet`.

**⭐ Recommended approach:** Use the [Manual Figma Export + Automated Processing](#recommended-workflow-manual-figma-export--automated-processing) workflow for production-quality assets at all scales (0.5x, 1x, 2x).

## Prerequisites

These tools must be available locally:

| Tool | Install | Purpose |
|------|---------|---------|
| `cwebp` | `brew install webp` | PNG/JPG to WebP conversion |
| `ffmpeg` | `brew install ffmpeg` | Video optimization and format conversion |
| `sips` | Built into macOS | Quick image dimension queries |
| `wrangler` | `npx wrangler` (via pnpm/npm) | Cloudflare R2 uploads |

Check availability before starting:
```bash
which cwebp ffmpeg sips && npx wrangler --version
```

## Recommended Workflow: Manual Figma Export + Automated Processing

**For best quality**, use this hybrid approach that combines manual Figma exports with automated processing:

### Why This Approach?

- ❌ **Figma MCP limitation**: Only returns single-scale image URLs (typically 1x/design size)
- ❌ **Local upscaling problem**: Using `sips` to upscale 1x → 2x produces lower quality than native Figma 2x exports
- ✅ **Native Figma exports**: Each scale (0.5x, 1x, 2x) is rendered from original vector/design data at that resolution
- ✅ **Automation**: Claude handles conversion, naming, upload, code updates, cleanup

### Workflow Steps

**1. Claude detects Figma asset and instructs:**
```
"Please export this node from Figma at 0.5x, 1x, 2x scales (PNG format)
and drop the .zip file in ./temp/ folder"
```

**2. User exports from Figma:**
- Select the node in Figma
- Open Export panel (right sidebar)
- Add export settings: 0.5x PNG, 1x PNG, 2x PNG
- Click "Export [asset-name]" → Downloads as `.zip` file

**3. User creates temp folder and drops .zip:**
```bash
# Create temp folder at project root (if it doesn't exist)
mkdir temp

# Move downloaded .zip from ~/Downloads/ to temp/
mv ~/Downloads/"Brand 2026 (N).zip" temp/
```

**4. Claude checks Cloudflare auth, user logs in if needed:**
```bash
npx --yes wrangler whoami
```
If not authenticated, ask the user to run:
```bash
npx wrangler login
```
This opens the browser for OAuth. Re-run `npx --yes wrangler whoami` to confirm.

**5. Claude automates the rest:**
- Unzips and finds PNG files
- Converts all to WebP (quality 85)
- Renames to convention: `{surface}-lp-{section}-{asset}%40{scale}.webp`
- Uploads to R2 (`assets-public` bucket, `/p/` prefix)
- Updates code references in constants.ts
- Deletes temp folder

### Example Flow

```bash
# After user drops Brand 2026 (26).zip in temp/:

# Claude executes:
unzip temp/"Brand 2026 (26).zip" -d temp/extracted
cd temp/extracted/wander.com

# Convert with correct naming (note: %40 = URL-encoded @)
cwebp -q 85 "ElevenLabs_..._1-1.png" -o "sites-lp-testimonial-2%400.5x.webp"
cwebp -q 85 "ElevenLabs_..._1.png" -o "sites-lp-testimonial-2%401x.webp"
cwebp -q 85 "ElevenLabs_..._1@2x.png" -o "sites-lp-testimonial-2%402x.webp"

# Upload to R2 (with account ID set)
export CLOUDFLARE_ACCOUNT_ID=026c91fc5cd3dd05f22c65e8f237ca2c
CLOUDFLARE_ACCOUNT_ID=026c91fc5cd3dd05f22c65e8f237ca2c bunx wrangler r2 object put assets-public/p/sites-lp-testimonial-2%400.5x.webp --file=/absolute/path/to/file.webp --content-type=image/webp --remote
CLOUDFLARE_ACCOUNT_ID=026c91fc5cd3dd05f22c65e8f237ca2c bunx wrangler r2 object put assets-public/p/sites-lp-testimonial-2%401x.webp --file=/absolute/path/to/file.webp --content-type=image/webp --remote
CLOUDFLARE_ACCOUNT_ID=026c91fc5cd3dd05f22c65e8f237ca2c bunx wrangler r2 object put assets-public/p/sites-lp-testimonial-2%402x.webp --file=/absolute/path/to/file.webp --content-type=image/webp --remote

# Update constants.ts
# image: `${CDN_BASE}/sites-lp-testimonial-2%401x.webp`

# Cleanup
rm -rf temp/
```

### Critical Details

**R2 Upload Settings:**
- Bucket: `assets-public` (serves `assets.wander.com`)
- Account ID: `026c91fc5cd3dd05f22c65e8f237ca2c` (set as env var)
- Must use `--remote` flag for actual cloud upload (not local R2 instance)
- Object key MUST include `/p/` prefix: `assets-public/p/listed-lp-hero-bg-light%401x.webp`
  - The CDN maps `https://assets.wander.com/p/` → R2 `assets-public/p/` prefix
  - Uploading without `/p/` silently succeeds but results in CDN 404s
- Object key naming: Use `%40` (URL-encoded @) in the actual key name for compatibility

**URL Encoding Note:**
- R2 object keys MUST use `%40` instead of literal `@` (e.g. `listed-lp-hero-bg-light%401x.webp`)
- Template literals in constants.ts MUST also use `%40` (e.g. `` `${CDN_BASE}/listed-lp-hero-bg-light%401x.webp` ``)
- Reason: browsers automatically percent-encode `@` → `%40` in URL paths, so `@` keys in R2 won't be found
- curl may return 200 for both forms (it doesn't encode `@`), but browsers always request `%40`

### Quality Comparison

| Approach | 0.5x Quality | 1x Quality | 2x Quality |
|----------|-------------|-----------|------------|
| **Figma MCP + sips** | ✅ Good (downscaled) | ✅ Good (native) | ❌ Poor (upscaled) |
| **Manual Figma export** | ✅ Excellent (native) | ✅ Excellent (native) | ✅ Excellent (native) |

**Bottom line:** Manual export workflow adds ~30 seconds of user work but delivers production-quality assets at all scales.

## Lessons Learned & Troubleshooting

### Common Issues

**1. Bash Commands Failing (Exit Code 1)**

If all bash commands suddenly fail (even `echo "test"`), this indicates a shell/permission issue:

**Solution:** User must restart Claude Code
- Cause: Unknown shell hook or permission block
- Frequency: Occurred 3-4 times during extended sessions
- Detection: Even simple commands like `whoami` or `echo` fail with exit code 1
- After restart: All bash functionality returns immediately

**2. Figma Export Naming Inconsistency**

Figma exports have unpredictable naming patterns for multi-scale exports:

| Pattern A | Pattern B | Pattern C |
|-----------|-----------|-----------|
| `Name@2x.png` | `Name.png` | `Name-2.png` |
| `Name.png` | `Name-1.png` | `Name-1.png` |
| `Name-1.png` | `Name-2.png` | `Name.png` |

**Solution:** Always identify scales by dimensions, not filenames
```bash
# Check dimensions first
sips -g pixelWidth -g pixelHeight *.png

# Example dimensions for 16:9 video thumbnails:
# 529×298   = 0.5x
# 1058×596  = 1x
# 2116×1191 = 2x
```

**3. Overwriting Existing Files**

When re-uploading assets with the same name:

**Solution:** Just upload - no need to delete first
- R2 automatically overwrites objects with matching keys
- CDN updates within seconds (check `last-modified` header)
- No duplicate files created if using consistent `%40` encoding

**4. Alpha Transparency**

UI screenshots (property pages, interface mockups) often have transparency:

**Solution:** `cwebp` automatically preserves alpha channels
```bash
cwebp -q 85 input.png -o output.webp
# Output shows: "Dimension: X x Y (with alpha)"
# Lossless-alpha compressed size: X bytes
```

No special flags needed - transparency is preserved by default.

### Best Practices

1. **Always use `%40` in R2 object keys** (not literal `@`)
2. **Identify scales by dimensions** (not Figma filenames)
3. **Overwrite is safe** (no need to delete first)
4. **Quality 85 is the default** (increase only if visible artifacts)
5. **Verify CDN with curl** (check `last-modified` for freshness)
6. **Alpha transparency works automatically** (no special handling needed)

## Naming Conventions

### Images

Pattern: `{surface}-lp-{section}-{asset}[-theme]@{scale}.webp`

Examples:
```text
travel-agents-lp-cta-background@0.5x.webp
travel-agents-lp-cta-background@1x.webp
travel-agents-lp-cta-background@2x.webp
travel-agents-lp-how-it-works-1@2x.webp
sites-lp-audit-background@2x.webp
sites-lp-audit-foreground@1x.webp
sites-lp-audit-foreground-dark@1x.webp
```

Rules:
- Lowercase, hyphen-separated
- Start with the surface/page prefix (`sites`, `travel-agents`, etc.)
- Include `lp` as the landing-page marker after the surface prefix
- Use a section token that can be multi-word (`how-it-works`, `audit`, `cta`)
- Put variant index at the end of the asset token when needed (`...-1`, `...-2`)
- Theme suffix is optional and should be appended only for explicit variants (`-dark`)
- Scale suffix: `@0.5x`, `@1x`, `@2x`
- Always WebP for images

### Videos

Pattern: `{surface}-lp-{section}-{asset}[-theme].mp4`

Examples:
```text
travel-agents-lp-hero-loop.mp4
travel-agents-lp-hero-loop-dark.mp4
sites-lp-features-1.mp4
sites-lp-features-1-dark.mp4
```

## Image Conversion (PNG to WebP)

### Single image

```bash
cwebp -q 85 input.png -o output.webp
```

Quality guidelines:
- **85** - Default for hero images, backgrounds, photos
- **80** - Acceptable for smaller thumbnails, cards
- **90** - Use only when quality loss is clearly visible at 85

### Batch convert all PNGs in a directory

```bash
for f in *.png; do
  cwebp -q 85 "$f" -o "${f%.png}.webp"
done
```

### Convert Figma multi-scale exports

When Figma exports at 0.5x, 1x, 2x (PNG), convert all to WebP:

```bash
for f in *@0.5x.png *@1x.png *@2x.png; do
  [ -f "$f" ] && cwebp -q 85 "$f" -o "${f%.png}.webp"
done
```

### Get image dimensions (for srcSet width descriptors)

```bash
sips -g pixelWidth -g pixelHeight image@1x.webp
```

Or for all WebP files:
```bash
for f in *.webp; do
  printf "%-50s " "$f"
  sips -g pixelWidth "$f" 2>/dev/null | grep pixelWidth | awk '{print $2 "w"}'
done
```

## Video Optimization

### Compress MP4 for web

```bash
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset slow -movflags +faststart -an output.mp4
```

Flags:
- `-crf 23` - Quality (lower = better, 18-28 is useful range)
- `-preset slow` - Better compression (use `medium` for faster encoding)
- `-movflags +faststart` - Enables progressive playback
- `-an` - Strip audio (common for background/hero videos)

### Convert to WebM (smaller, broader codec support)

```bash
ffmpeg -i input.mp4 -c:v libvpx-vp9 -crf 30 -b:v 0 -an output.webm
```

### Trim video

```bash
ffmpeg -i input.mp4 -ss 00:00:02 -to 00:00:10 -c copy trimmed.mp4
```

### Create poster frame from video

```bash
ffmpeg -i video.mp4 -frames:v 1 -q:v 2 poster.jpg
cwebp -q 85 poster.jpg -o poster.webp
```

## Upload to Cloudflare R2

### Authentication

Wrangler must be authenticated. Check with:
```bash
npx --yes wrangler whoami
```

If not authenticated, the user must log in first:
```bash
npx wrangler login
```

This command launches the OAuth login flow in the browser.

If multiple Cloudflare accounts are available, set the target account for non-interactive commands:
```bash
export CLOUDFLARE_ACCOUNT_ID=<account-id-from-wrangler-whoami>
```

### List buckets

```bash
npx --yes wrangler r2 bucket list
```

### Upload a single file

```bash
npx wrangler r2 object put {BUCKET_NAME}/p/{filename} --file={local-path}
```

The `/p/` prefix maps to the CDN path `https://assets.wander.com/p/`.

### Upload all WebP files from a directory

```bash
for f in *.webp; do
  echo "Uploading $f..."
  npx wrangler r2 object put {BUCKET_NAME}/p/"$f" --file="$f"
done
```

### Upload with content-type header

```bash
npx wrangler r2 object put {BUCKET_NAME}/p/video.mp4 --file=video.mp4 --content-type="video/mp4"
```

### Verify upload

```bash
npx wrangler r2 object get {BUCKET_NAME}/p/{filename} --pipe > /dev/null && echo "OK"
```

Or check via CDN URL:
```bash
curl -sI "https://assets.wander.com/p/{filename}" | head -5
```

## Generating srcSet Strings for Code

### Pattern

The codebase uses this TypeScript pattern for responsive images:

```typescript
const CDN_BASE = 'https://assets.wander.com/p';

// Single theme image
const image = {
  src: `${CDN_BASE}/name@2x.webp`,
  srcSet: `${CDN_BASE}/name@0.5x.webp {0.5xWidth}w, ${CDN_BASE}/name@1x.webp {1xWidth}w, ${CDN_BASE}/name@2x.webp {2xWidth}w`,
};

// Light/dark theme image pair (for ThemeAwareImage)
const image = {
  light: {
    src: `${CDN_BASE}/name-light@2x.webp`,
    srcSet: `${CDN_BASE}/name-light@0.5x.webp {w}w, ${CDN_BASE}/name-light@1x.webp {w}w, ${CDN_BASE}/name-light@2x.webp {w}w`,
  },
  dark: {
    src: `${CDN_BASE}/name-dark@2x.webp`,
    srcSet: `${CDN_BASE}/name-dark@0.5x.webp {w}w, ${CDN_BASE}/name-dark@1x.webp {w}w, ${CDN_BASE}/name-dark@2x.webp {w}w`,
  },
};
```

### Generate srcSet from local files

After converting to WebP, get the actual pixel widths and generate the srcSet:

```bash
# Get widths for a set of files
for scale in 0.5x 1x 2x; do
  f="sites-lp-hero-bg-light@${scale}.webp"
  w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
  echo "${f} ${w}w"
done
```

Then construct the srcSet string using those widths.

### Default `src` is always the @2x variant

The `src` property (used as fallback) should always point to the `@2x` version.

## Full Workflow Example

Complete flow for a new hero background image:

```bash
# 1. Verify tools
which cwebp sips && npx wrangler --version

# 2. Convert Figma PNG exports to WebP
cd ~/Downloads/figma-exports
cwebp -q 85 sites-lp-hero-bg-light@0.5x.png -o sites-lp-hero-bg-light@0.5x.webp
cwebp -q 85 sites-lp-hero-bg-light@1x.png -o sites-lp-hero-bg-light@1x.webp
cwebp -q 85 sites-lp-hero-bg-light@2x.png -o sites-lp-hero-bg-light@2x.webp

# 3. Check dimensions
for f in sites-lp-hero-bg-light@*.webp; do
  printf "%-50s " "$f"
  sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2 "w"}'
done

# 4. Upload to R2
for f in sites-lp-hero-bg-light@*.webp; do
  npx wrangler r2 object put {BUCKET_NAME}/p/"$f" --file="$f"
done

# 5. Verify via CDN
curl -sI "https://assets.wander.com/p/sites-lp-hero-bg-light@2x.webp" | head -3

# 6. Output shows e.g.:
#   sites-lp-hero-bg-light@0.5x.webp  1022w
#   sites-lp-hero-bg-light@1x.webp    2044w
#   sites-lp-hero-bg-light@2x.webp    4088w
#
# Use in code:
# srcSet: `${CDN_BASE}/sites-lp-hero-bg-light@0.5x.webp 1022w, ${CDN_BASE}/sites-lp-hero-bg-light@1x.webp 2044w, ${CDN_BASE}/sites-lp-hero-bg-light@2x.webp 4088w`
```

## Reference

- Asset constants pattern: `src/app/(hs_tracking)/sites/constants.ts`
- ThemeAwareImage component: `src/app/(hs_tracking)/sites/_components/shared/ThemeAwareImage.tsx`
- CDN base URL: `https://assets.wander.com/p`
- R2 path prefix: `/p/`
- Cloudflare wrangler R2 docs: `npx wrangler r2 --help`
