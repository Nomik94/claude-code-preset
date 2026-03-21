# Core Web Vitals 최적화 규칙 상세

## Core Web Vitals 목표

| 지표 | 목표 | 설명 |
|------|------|------|
| LCP (Largest Contentful Paint) | < 2.5초 | 최대 콘텐츠 요소 렌더 시간 |
| FID (First Input Delay) | < 100ms | 첫 인터랙션 응답 지연 |
| CLS (Cumulative Layout Shift) | < 0.1 | 누적 레이아웃 이동 점수 |
| INP (Interaction to Next Paint) | < 200ms | 인터랙션 응답 시간 (FID 대체) |

## 리스트 가상화

50개 이상 아이템 리스트는 가상화 필수.

```tsx
// Bad: 1000개 아이템 전부 렌더
{items.map(item => <Row key={item.id} {...item} />)}

// Good: 가상화
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              transform: `translateY(${virtualItem.start}px)`,
              height: `${virtualItem.size}px`,
            }}
          >
            <Row item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

## 레이아웃 읽기 배칭

`offsetHeight`, `getBoundingClientRect()` 등 레이아웃 읽기를 쓰기와 분리.

```tsx
// Bad: 강제 리플로우 (읽기-쓰기-읽기)
element.style.width = '100px';
const height = element.offsetHeight;
element.style.height = height + 'px';

// Good: 읽기를 먼저, 쓰기를 나중에
const height = element.offsetHeight;
requestAnimationFrame(() => {
  element.style.width = '100px';
  element.style.height = height + 'px';
});
```

## 폰트 최적화

### preload

```html
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin />
```

### Next.js font

```tsx
import { Inter } from 'next/font/google';
const inter = Inter({ subsets: ['latin'] });
```

### font-display

```css
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap;  /* 폴백 폰트 먼저 표시 */
}
```

## 이미지 최적화

### lazy loading

```tsx
// Above the fold 이미지: 즉시 로드
<img src="/hero.jpg" alt="hero" loading="eager" />

// Below the fold 이미지: 지연 로드
<img src="/below-fold.jpg" alt="content" loading="lazy" />
```

### Next.js Image

```tsx
import Image from 'next/image';

// priority: LCP 이미지에 사용
<Image src="/hero.png" alt="hero" width={800} height={400} priority />

// 일반 이미지: 자동 lazy loading
<Image src="/photo.png" alt="photo" width={400} height={300} />
```

### CLS 방지

이미지에 width/height 명시하여 레이아웃 시프트 방지.

```tsx
// Bad: 크기 미지정 -> CLS 발생
<img src="/photo.jpg" alt="photo" />

// Good: 크기 명시
<img src="/photo.jpg" alt="photo" width={400} height={300} />
```

## 디바운스/스로틀

빈번한 이벤트(scroll, resize, input)에 디바운스 적용.

```tsx
import { useDebouncedCallback } from 'use-debounce';

const handleSearch = useDebouncedCallback((value: string) => {
  search(value);
}, 300);
```

## CSS Containment

독립적 섹션에 `contain` 적용으로 렌더링 범위 제한.

```css
/* 독립적 카드/섹션 */
.card {
  contain: layout style paint;
}

/* 뷰포트 밖 섹션 */
.offscreen-section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px;
}
```

## 애니메이션 성능

### transform/opacity만 사용

```css
/* Bad: 레이아웃 트리거 */
.slide { transition: left 0.3s ease; }

/* Good: 합성 레이어만 */
.slide { transition: transform 0.3s ease; }
```

### transition: all 금지

```css
/* Bad */
.card { transition: all 0.3s ease; }

/* Good */
.card { transition: opacity 0.3s ease, transform 0.3s ease; }
```

### will-change 남용 금지

```css
/* Bad: 항상 적용 */
.element { will-change: transform; }

/* Good: 호버 시에만 */
.element:hover { will-change: transform; }
```

## 측정 도구

```bash
# Lighthouse CLI
npx lighthouse https://example.com --output=json --chrome-flags="--headless"
```

```tsx
// Web Vitals 라이브러리
import { onCLS, onFID, onLCP, onINP } from 'web-vitals';

onCLS(console.log);
onFID(console.log);
onLCP(console.log);
onINP(console.log);
```
