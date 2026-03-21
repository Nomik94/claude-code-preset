# 번들 최적화 상세

## 배럴 파일 금지

`export * from` 패턴은 tree-shaking을 방해한다.

```tsx
// Bad: 배럴 파일 (index.ts)
export * from './Button';
export * from './Modal';
export * from './Table';

// 사용측에서 하나만 써도 전부 번들링됨
import { Button } from '@/components';

// Good: 직접 임포트
import { Button } from '@/components/Button';
```

### 배럴 파일 대안

```
components/
  Button/
    Button.tsx
    Button.test.tsx
    index.ts        # 단일 컴포넌트 re-export만 허용
  Modal/
    Modal.tsx
    index.ts
```

단일 컴포넌트 폴더의 `index.ts`는 허용 (해당 컴포넌트만 export).
여러 컴포넌트를 묶는 최상위 `components/index.ts`는 금지.

## Dynamic Import로 코드 스플릿

초기 로드에 불필요한 컴포넌트는 `next/dynamic` 사용.

```tsx
// Bad: 무조건 번들 포함
import { HeavyEditor } from '@/components/HeavyEditor';

// Good: 필요 시 로드
import dynamic from 'next/dynamic';
const HeavyEditor = dynamic(() => import('@/components/HeavyEditor'), {
  loading: () => <EditorSkeleton />,
});
```

### Dynamic Import 적용 대상

| 대상 | 이유 |
|------|------|
| 리치 텍스트 에디터 | 큰 번들 크기 |
| 차트/그래프 라이브러리 | D3, Chart.js 등 |
| 모달/다이얼로그 콘텐츠 | 초기 로드 불필요 |
| 관리자 전용 기능 | 일반 사용자에게 불필요 |
| 코드 하이라이터 | Prism, Shiki 등 |

### SSR 비활성화

클라이언트 전용 컴포넌트는 SSR 비활성화.

```tsx
const MapComponent = dynamic(() => import('@/components/Map'), {
  ssr: false,
  loading: () => <MapSkeleton />,
});
```

## Tree-Shaking 확인

### Bundle Analyzer 설정

```bash
pnpm add -D @next/bundle-analyzer
```

```js
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer(nextConfig);
```

```bash
ANALYZE=true pnpm build
```

### Tree-Shaking 방해 요소

| 패턴 | 문제 | 해결 |
|------|------|------|
| `export *` | 모든 export 번들링 | named export 직접 import |
| CommonJS (`require`) | 정적 분석 불가 | ESM (`import`) 사용 |
| Side-effect import | 제거 불가 | `sideEffects: false` in package.json |
| `eval()` 사용 | 정적 분석 불가 | 제거 |

## 패키지 크기 의식

무거운 라이브러리 도입 전 번들 크기 확인.

| 무거운 패키지 | 가벼운 대안 | 절감 |
|-------------|-----------|------|
| moment | date-fns | ~90% |
| lodash | lodash-es (tree-shakeable) | ~80% |
| classnames | clsx | ~50% |
| uuid | crypto.randomUUID() | 100% (내장) |
| axios | fetch (내장) | 100% |

### 번들 크기 확인 명령

```bash
# bundlephobia CLI
npx bundlephobia-cli react-query

# import-cost VSCode 확장도 추천
```
