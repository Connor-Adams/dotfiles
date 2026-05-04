---
name: wander-ui
description: Build landing pages and marketing pages using the Wander design system grid, typography, buttons, and light/dark theming. Use when creating new pages, sections, or components that need the Grid/GridItem layout, Heading/Text/Button components, ThemeAwareImage, or data-theme dark mode patterns.
---

# Wander UI — Design System & Theming Patterns

## Grid System

Import from `@wandercom/design-system-web/ui/grid`.

### Grid component

Two layout variants:
- `layout='default'` — 1576px max-width, **2/6/12 columns** (base/md/lg). Use for most pages.
- `layout='wide'` — 1832px max-width, **2/3/4/5/6/7 columns** (base/md/lg/xl/3xl/4xl). Use for property listings.

Both include `mx-auto`, responsive padding, and `1rem` gap.

### GridItem component

Props:
- `span` — Column span: `1-12` or `'full'`. Accepts responsive object `{ base, sm, md, lg, xl, 2xl, 3xl, 4xl }`.
- `start` — Column start position: `1-12`. Accepts same responsive object.

### Standard layout pattern — centered 10 of 12 columns

This is the most common pattern across landing pages:

```tsx
import { Grid, GridItem } from '@wandercom/design-system-web/ui/grid';

<Grid layout='default' className='w-full'>
  <GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }}>
    {/* Content centered in 10 cols with 1-col margins on desktop */}
  </GridItem>
</Grid>
```

### Two-column asymmetric layout (e.g. sidebar + main)

Use raw CSS grid inside a GridItem when you need sub-grid layouts:

```tsx
<GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }}>
  <div className='grid grid-cols-10 gap-x-4'>
    <div className='col-span-3'>{/* Sidebar */}</div>
    <div className='col-span-7'>{/* Main content */}</div>
  </div>
</GridItem>
```

### Two-column split layout (e.g. heading left, content right)

```tsx
<Grid layout='default' className='w-full'>
  <GridItem span={{ base: 2, md: 6, lg: 4 }} start={{ base: 1, md: 1, lg: 2 }}>
    {/* Left: heading */}
  </GridItem>
  <GridItem span={{ base: 2, md: 6, lg: 5 }} start={{ base: 1, md: 1, lg: 7 }}>
    {/* Right: content */}
  </GridItem>
</Grid>
```

### Mobile horizontal scroll that bleeds to viewport edges

Break out of the grid container on mobile, then switch to a CSS grid on desktop:

```tsx
{/* Desktop: grid */}
<GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }} className='hidden lg:block'>
  <div className='grid grid-cols-3 gap-4'>
    {items.map((item) => <Card key={item.id} {...item} />)}
  </div>
</GridItem>

{/* Mobile: horizontal scroll, bleeds to viewport edges */}
<GridItem span='full' className='lg:hidden'>
  <div className='mx-[calc(50%-50vw)]'>
    <div className='flex gap-4 overflow-x-auto px-6 pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden'>
      {items.map((item) => <Card key={item.id} {...item} />)}
    </div>
  </div>
</GridItem>
```

Key: `mx-[calc(50%-50vw)]` breaks a contained element to full viewport width.

## Typography

### Heading

```tsx
import { Heading } from '@wandercom/design-system-web/ui/heading';
```

**Variants** (responsive): `display-lg`, `display`, `display-sm`, `headline-lg`, `headline`, `headline-sm`
**Colors**: `primary`, `secondary`, `tertiary`
**Element**: `as='h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6'`

```tsx
<Heading variant={{ base: 'display', md: 'display-lg' }} as='h1'>
  Page title
</Heading>

{/* Secondary color for subtitle spans */}
<Heading variant='headline-lg' as='h2'>
  Main text. <span className='text-secondary'>Muted text.</span>
</Heading>
```

### Text

```tsx
import { Text } from '@wandercom/design-system-web/ui/text';
```

**Variants** (responsive): `body-lg-long`, `body-lg`, `body-long`, `body`, `body-sm`
**Weight**: `normal` (450), `medium` (550)
**Colors**: `primary`, `secondary`, `tertiary`
**Element**: `as='p' | 'span' | 'h1'-'h6'`

```tsx
<Text variant='body-lg' color='tertiary'>
  Description text
</Text>
<Text variant='body' weight='medium'>Bold label</Text>
```

## Button

```tsx
import { Button } from '@wandercom/design-system-web/ui/button';
```

**Variants**: `primary`, `secondary`, `outline`, `ghost`, `destructive`, `checkout`, `link`, `unstyled`
**Sizes**: `sm`, `md`, `lg`, `icon-sm`, `icon-md`, `icon-lg`

```tsx
<Button variant='primary' size='md'>Get started</Button>

{/* As link using asChild */}
<Button asChild variant='primary' size='lg'>
  <Link href='/signup'>Sign up</Link>
</Button>
```

## Light / Dark Mode

### How it works

Dark mode is driven by the `data-theme` attribute on ancestor elements, **not** the Tailwind `class` strategy. A custom variant is defined in `src/app/tailwind.css`:

```css
@custom-variant dark {
  &:where([data-theme="dark"] *, [data-theme="dark"]) {
    @slot;
  }
}
```

This means `dark:` Tailwind utilities work based on the nearest `data-theme="dark"` ancestor.

### Semantic surface tokens

Use these instead of raw colors — they auto-adapt to the active theme:

| Utility class | Purpose |
|---|---|
| `bg-surface-primary` | Main background |
| `bg-surface-secondary` | Secondary/card background |
| `bg-surface-tertiary` | Tertiary background |
| `text-content-primary` | Primary text |
| `text-primary` | Primary text (shorthand) |
| `text-secondary` | Muted text |
| `border-border-secondary` | Standard borders |
| `bg-primary` | Solid primary fill (inverted text) |

### Layout-level theme setup

Landing page layouts apply the theme class and CSS variable scope:

```tsx
// layout.tsx
<main className='bg-surface-primary text-content-primary sites-page-body'>
  {children}
</main>
```

The `sites-page-body` class triggers theme-specific CSS variable overrides defined in `src/app/(hs_tracking)/styles.css`. These map semantic tokens to neutral-scale colors for each theme.

### Section-level theme forcing

Force a section to always be dark regardless of page theme:

```tsx
<section data-theme='dark' className='bg-black py-20 md:py-[120px]'>
  {/* All children here use dark theme tokens */}
</section>
```

### Conditional dark mode classes

```tsx
{/* Gradients */}
<div className='bg-linear-to-b from-white to-transparent dark:from-black dark:to-transparent' />

{/* Borders and shadows */}
<div className='border border-black/5 dark:border-white/10 dark:shadow-[0px_4px_8px_0px_rgba(0,0,0,0.64)]' />

{/* Opacity overlay */}
<div className='bg-surface-primary/80 backdrop-blur-sm' />
```

### ThemeAwareImage — dual light/dark images

Located at `src/components/Marketing/ThemeAwareImage.tsx`.

Renders both images and hides one via `dark:hidden` / `light:hidden`:

```tsx
import ThemeAwareImage, { type ImageSrcInfo } from '@/components/Marketing/ThemeAwareImage';

const heroImage: ImageSrcInfo = {
  light: {
    src: 'https://assets.wander.com/p/hero-light@2x.webp',
    srcSet: 'https://assets.wander.com/p/hero-light@0.5x.webp 1022w, https://assets.wander.com/p/hero-light@1x.webp 2044w',
  },
  dark: {
    src: 'https://assets.wander.com/p/hero-dark@2x.webp',
    srcSet: 'https://assets.wander.com/p/hero-dark@0.5x.webp 1022w, https://assets.wander.com/p/hero-dark@1x.webp 2044w',
  },
};

<ThemeAwareImage srcInfo={heroImage} sizes='100vw' alt='Hero' className='h-full w-full object-cover' />
```

### Theme-aware video (StickyVideoPlayer pattern)

Render separate light/dark `<video>` elements and toggle visibility:

```tsx
<video className='dark:hidden' ...>{/* light video */}</video>
<video className='hidden dark:block' ...>{/* dark video */}</video>
```

See `src/app/(hs_tracking)/sites/_components/StickyVideoPlayer.tsx` for the full implementation including fade transitions.

## Common Section Pattern

Standard section structure used across the sites pages:

```tsx
<section className='flex w-full flex-col items-center justify-center py-20 md:py-[120px]'>
  <Grid layout='default' className='w-full gap-y-10'>
    {/* Header */}
    <GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }}>
      <Heading variant={{ base: 'headline-lg', md: 'display' }} as='h2'>
        Section title <br className='hidden sm:block' /> <span className='text-tertiary'>Subtitle in muted color.</span>
      </Heading>
    </GridItem>

    {/* Content */}
    <GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }}>
      {/* Section content */}
    </GridItem>
  </Grid>
</section>
```

## Sticky Scroll Pattern (IntersectionObserver)

Used in the features section — text items scroll while a video stays pinned:

```tsx
const refs = React.useRef<(HTMLDivElement | null)[]>([]);
const [activeIndex, setActiveIndex] = React.useState(0);

React.useEffect(() => {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const index = refs.current.indexOf(entry.target as HTMLDivElement);
          if (index !== -1) setActiveIndex(index);
        }
      });
    },
    { threshold: 0.5, rootMargin: '-20% 0px -20%' }
  );
  refs.current.forEach((ref) => { if (ref) observer.observe(ref); });
  return () => observer.disconnect();
}, []);

{/* Sticky media */}
<div className='sticky top-1/4'>
  <VideoOrImage activeIndex={activeIndex} />
</div>
```

## Best Practices

### Horizontal Padding

**Rely on the Grid system** for horizontal padding instead of manual padding classes. Designers typically use **columns 2-11** (not the full 1-12 span) to create natural margins:

```tsx
{/* Design pattern: 10 of 12 columns with 1-column margins on each side */}
<GridItem span={{ base: 'full', lg: 10 }} start={{ lg: 2 }}>
  {/* Content is automatically padded by unused grid columns */}
</GridItem>
```

This approach ensures consistent horizontal spacing across the site and matches design specs without manual padding calculations.

### Vertical Padding

**Always check Figma directly** for vertical spacing. Hover over sections in Figma and screenshot the spacing measurements for:
- Mobile view
- Tablet view
- Desktop view

Don't guess or use arbitrary values. Figma will show exact `pt-*` and `pb-*` values that designers intend. Typical patterns:
- Small sections: `py-12 md:py-16 lg:py-20`
- Medium sections: `py-16 md:py-20 lg:py-24`
- Large sections: `py-20 md:py-[120px]`

### Image Sizing

**Use aspect ratios, not fixed heights**. This ensures images scale properly across devices:

```tsx
{/* ✅ Good: aspect ratio */}
<div className='relative w-full' style={{ aspectRatio: '16 / 9' }}>
  <Image src={src} fill className='object-cover' />
</div>

{/* ❌ Avoid: fixed height */}
<div className='relative w-full h-[400px]'>
  <Image src={src} fill className='object-cover' />
</div>
```

Common aspect ratios: `16/9`, `4/3`, `1/1`, `362/241.33`.

### Asset Pipeline

For processing Figma exports and uploading images, use the **asset-pipeline skill**:
- Converts images to WebP format
- Generates responsive srcSet strings
- Optimizes and uploads to Cloudflare R2/CDN
- Handles both images and videos

See `/asset-pipeline` skill for details.

## Reference files

- Grid/section examples: `src/app/(hs_tracking)/sites/page.tsx`
- Hero with gradient overlays: `src/app/(hs_tracking)/sites/_components/SitesHeroSection.tsx`
- Sticky video + IntersectionObserver: `src/app/(hs_tracking)/sites/_components/FeaturesSection.tsx`
- Horizontal scroll cards: `src/app/(hs_tracking)/sites/_components/SitesTestimonialsSection.tsx`
- ThemeAwareImage component: `src/components/Marketing/ThemeAwareImage.tsx`
- Theme CSS variables: `src/app/(hs_tracking)/styles.css`
- Tailwind custom variants: `src/app/tailwind.css`
- StickyVideoPlayer: `src/app/(hs_tracking)/sites/_components/StickyVideoPlayer.tsx`
