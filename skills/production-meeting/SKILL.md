# CineBot 영상 제작 (Production Meeting)

AI 영상 제작 시나리오를 생성합니다. C안 3단계 파이프라인 기반.

## 실행 조건

사용자가 다음과 같이 요청하면 실행:
- "제작 회의 해줘"
- "시나리오 분석해줘"
- "영상 기획해줘"
- `/production-meeting`

## 파이프라인 (C안 3단계)

```
Step 0: Claude 프롬프트 안전 변환 (콘텐츠 모더레이션 우회)
Step 1: grok-imagine-image (드래프트, $0.02) → 씬 이미지
Step 2: grok-imagine-image-pro (리파인, $0.07) → 고품질 이미지
Step 3: grok-imagine-video (I2V, $0.02~0.05/초) → 영상
```

## 제작진 (5명 비주얼 디자이너)

| # | 역할 | 스타일 참조 | 담당 |
|---|------|-----------|------|
| 1 | 아트 디렉터 | 신카이 마코토 | 비주얼 톤, 뉴스 주제별 무드 자동 결정 |
| 2 | 배경 디자이너 | CNN/Bloomberg | 씬별 배경 구체적 묘사, 디스플레이 변경 |
| 3 | 조명 디자이너 | Makoto Shinkai palette | 빛/색감, bloom/lens flare/light rays |
| 4 | 캐릭터 연출 | — | action/expression 자연스러운 동작/표정 |
| 5 | 품질 관리 | — | 품질 태그, 캐릭터 일관성 검증 |

## 핵심 규칙 (prompt_rules.py 기준)

### video_prompt
- 영문 필수, AI 이미지 API에 직접 입력
- 첫 20-30단어가 최우선, 50-150단어 최적
- 구체적 색상/감정 (not 'colorful' but 'electric blue and hot pink')
- 영화 전문용어 금지 (no dolly, crane, f/1.8)
- montage/split screen 금지

### 캐릭터 일관성
- 씬 1에서 정의 → 모든 씬 word-for-word 동일 복사
- 변경 가능: 포즈, 표정, 액션, 배경
- 변경 불가: 머리색, 눈색, 의상, 체형, 나이, 아트 스타일

### 나레이션
- 내레이터 화법 필수 (장면 묘사/지문 금지)
- 뉴스: 앵커 스타일 ('~했습니다')
- 이야기: 스토리텔러 ('~했죠', '~이었습니다')

### 뉴스 모드 (style: news/breaking/report/anchor)
- 앵커 상반신만 (waist up), 전신 금지
- 여성: low-cut black tank top / 남성: open collar dark suit
- CNN/Bloomberg 스타일 리얼 스튜디오
- 주제별 무드: 경제=navy+gold, 전쟁=blue+red, 기술=cyan+white

### 일반 모드
- 스토리 설정에 따라 자유
- 캐릭터 일관성 + 품질 태그 + action/expression/camera

### 콘텐츠 안전
- 섹슈얼/테러/인종차별/유아/고어 → Claude가 자동 우회 변환
- 일반 뉴스 단어(전쟁/납치 등)는 통과

### I2V 프롬프트 (영상 생성)
- 20-40단어, 동작/카메라/오디오만
- 이미지에 있는 것을 재서술하지 않음
- 뉴스: "Audio: no music, quiet ambient"
- 일반: "Audio: soft [bgm_mood] background music"

## 비용

| 구성 | 480p | 720p |
|------|------|------|
| 30초 3씬 | $0.87 (₩1,242) | $1.77 (₩2,528) |
| 30초 5씬 | $1.05 (₩1,499) | $1.95 (₩2,785) |

## 소스 코드 참조

- `python-server/services/prompt_rules.py` — 프롬프트 규칙 Single Source of Truth
- `python-server/routers/scenario.py` — UI 시나리오 생성
- `python-server/routers/grok_video.py` — C안 3단계 파이프라인
- `python-server/telegram_bot/services/news_scenario_service.py` — 텔레그램
- `docs/research/grok_video_prompt_guide.md` — 프롬프트 리서치 가이드
- `docs/research/cinebot_cost_analysis.md` — 비용 분석
