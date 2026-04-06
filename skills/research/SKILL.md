# 멀티도메인 리서치 스킬

사용자가 `/research` 명령어를 실행하면 AI, 블록체인, 테슬라 3대 도메인의 최신 정보를 웹 검색으로 수집하고 구조화된 JSON으로 반환합니다.

---

## 사용법

```bash
/research ai                    # AI 도메인 최신 뉴스/논문/블로그
/research blockchain             # 블록체인/크립토 최신 뉴스/온체인
/research tesla                  # 테슬라/EV/SpaceX 최신 뉴스
/research all                    # 3개 도메인 전체
/research ai "GPT-5 출시"        # 특정 키워드 집중 리서치
```

---

## 실행 지침

### 1단계: 도메인 파싱 (대소문자/영문/한글 무관)

```
/research {domain} {keyword?}
```

**도메인 매핑 (아래 중 아무거나 입력해도 동일하게 동작)**:

| 입력 (대소문자 무관) | 매핑 도메인 |
|---------------------|-----------|
| `ai`, `AI`, `Ai`, `인공지능`, `에이아이` | → AI 도메인 |
| `blockchain`, `Blockchain`, `BLOCKCHAIN`, `블록체인`, `크립토`, `crypto`, `비트코인`, `bitcoin`, `web3` | → 블록체인 도메인 |
| `tesla`, `Tesla`, `TESLA`, `테슬라`, `머스크`, `musk`, `spacex`, `SpaceX`, `ev`, `EV`, `전기차` | → 테슬라 도메인 |
| `all`, `ALL`, `전체`, `모두`, `전부` | → 3개 도메인 전체 |

**파싱 규칙**:
1. 입력을 소문자로 변환 후 매칭
2. 매칭 안 되면 키워드 검색으로 간주 (3개 도메인 전체에서 해당 키워드 리서치)
3. 예: `/research GPT-5` → 키워드 "GPT-5"로 3개 도메인 검색

**예시**:
```bash
/research AI                    # OK
/research ai                    # OK
/research 인공지능               # OK
/research 에이아이               # OK
/research blockchain             # OK
/research 블록체인               # OK
/research 크립토                 # OK
/research crypto                 # OK
/research 비트코인               # OK
/research tesla                  # OK
/research 테슬라                 # OK
/research 머스크                 # OK
/research spacex                 # OK
/research 전기차                 # OK
/research all                    # OK
/research 전체                   # OK
/research ai "GPT-5 출시"        # AI 도메인 + 키워드
/research 블록체인 "이더리움 업그레이드"  # 블록체인 + 키워드
/research GPT-5                  # 키워드로 전체 도메인 검색
```

### 2단계: 도메인별 검색 실행

각 도메인별로 **공신력 검증된 Top 소스**를 중심으로 WebSearch를 수행합니다.
키워드가 주어지면 해당 키워드에 집중, 없으면 "최근 24시간 주요 뉴스"를 수집합니다.

---

## AI 도메인 (`/research ai`)

### 검색 쿼리 (순서대로 모두 실행)

```
1. "AI news today {날짜}" — 오늘 속보
2. "LLM GPT Claude Gemini news {날짜}" — LLM 관련
3. "AI research paper breakthrough {날짜}" — 논문/연구
4. "OpenAI Anthropic Google DeepMind announcement" — 기업 발표
5. site:reddit.com/r/MachineLearning top today — Reddit 트렌드
6. site:news.ycombinator.com AI LLM — Hacker News
7. "인공지능 뉴스" 오늘 — 한국어 소스
```

### 공신력 Top 소스 (이 소스의 정보를 우선)

**뉴스레터/미디어**: The Rundown AI(2M), TLDR AI(1.25M), TechCrunch, MIT Tech Review, Ars Technica, VentureBeat
**연구 블로그**: Lilian Weng(Lil'Log), Distill.pub, Jay Alammar, BAIR Blog, Simon Willison
**기업 블로그**: OpenAI Blog, Google AI Blog, Meta AI Blog, Anthropic Blog, HuggingFace Blog
**학술**: arXiv cs.AI/cs.CL/cs.CV, Papers With Code
**커뮤니티**: Reddit r/MachineLearning, r/LocalLLaMA, Hacker News

### 핵심 인물 동향 체크

Andrej Karpathy, Yann LeCun, Sam Altman, Dario Amodei, Jim Fan, François Chollet, Ilya Sutskever

---

## 블록체인 도메인 (`/research blockchain`)

### 검색 쿼리 (순서대로 모두 실행)

```
1. "crypto news today {날짜}" — 오늘 속보
2. "Bitcoin Ethereum DeFi news {날짜}" — 주요 코인
3. "blockchain regulation SEC {날짜}" — 규제 동향
4. "DeFi TVL onchain {날짜}" — 온체인 데이터
5. site:reddit.com/r/CryptoCurrency top today — Reddit 트렌드
6. "블록체인 암호화폐 뉴스" 오늘 — 한국어 소스
7. "Web3 DAO Layer2 news" — Web3 트렌드
```

### 공신력 Top 소스 (이 소스의 정보를 우선)

**프리미엄 미디어**: CoinDesk(업계 표준), The Block(데이터 저널리즘), Decrypt, Bloomberg Crypto, Reuters Crypto
**리서치**: Messari, Delphi Digital, Glassnode, Chainalysis, Nansen
**커뮤니티**: Bankless, The Defiant, Milk Road, Bitcoin Magazine, Blockworks
**온체인 데이터**: Dune Analytics, DefiLlama, Token Terminal, L2Beat
**한국**: 코인데스크코리아, 블록미디어, 토큰포스트, 디센터

### 핵심 인물 동향 체크

Vitalik Buterin, CZ, Brian Armstrong, Balaji Srinivasan, Chris Dixon, Ryan Sean Adams

---

## 테슬라 도메인 (`/research tesla`)

### 검색 쿼리 (순서대로 모두 실행)

```
1. "Tesla news today {날짜}" — 오늘 속보
2. "Tesla FSD autopilot update {날짜}" — 자율주행
3. "SpaceX Starship launch {날짜}" — SpaceX
4. "Elon Musk announcement {날짜}" — 머스크 동향
5. "Tesla stock TSLA analysis" — 투자 분석
6. site:reddit.com/r/TeslaMotors top today — Reddit 트렌드
7. "테슬라 뉴스" 오늘 — 한국어 소스
8. "EV electric vehicle battery {날짜}" — EV/배터리 산업
```

### 공신력 Top 소스 (이 소스의 정보를 우선)

**테슬라 전문**: Electrek(AI 인용 #97), Teslarati, Not A Tesla App(FSD 전문), Tesla Daily(Rob Maurer)
**EV 종합**: InsideEVs, CleanTechnica, The EV Report
**SpaceX**: NASASpaceflight, SpaceNews, Ars Technica Space
**투자**: ARK Invest, Gary Black/Future Fund, SEC EDGAR(CIK:0001318605)
**엔지니어링**: Munro Live(Sandy Munro), Battery Technology
**한국**: 테슬람, 한테타, EV Post

### 핵심 인물 동향 체크

Elon Musk, Sawyer Merritt, Whole Mars Catalog, Rob Maurer, Sandy Munro, Gary Black

---

## 3단계: 크로스 도메인 교차 감지

3개 도메인을 모두 검색한 경우(`/research all`), 교차점을 자동 감지합니다:

```
AI + 블록체인: "AI agents blockchain", "decentralized AI", "crypto AI tokens"
AI + 테슬라:   "Tesla FSD neural network", "Dojo supercomputer", "xAI Grok", "Optimus robot AI"
블록체인 + 테슬라: "Tesla Bitcoin", "SpaceX crypto", "Musk Dogecoin"
```

교차 주제가 발견되면 별도 섹션으로 하이라이트합니다.

---

## 4단계: 결과 구조화

### 출력 형식 (JSON)

```json
{
  "domain": "ai",
  "researched_at": "2026-04-05T12:00:00Z",
  "keyword": null,
  "top_stories": [
    {
      "rank": 1,
      "title": "뉴스 제목",
      "summary": "2~3문장 요약",
      "source": "출처명",
      "source_url": "URL",
      "source_credibility": "Tier 1",
      "community_signal": {"hn_points": 350, "reddit_upvotes": 1200},
      "video_potential": "높음/중간/낮음",
      "video_potential_reason": "왜 영상으로 만들 가치가 있는지",
      "published_at": "2026-04-05",
      "tags": ["LLM", "OpenAI", "GPT-5"],
      "related_people": ["Sam Altman"]
    }
  ],
  "key_people_updates": [
    {
      "person": "Andrej Karpathy",
      "platform": "X/Blog",
      "summary": "최근 발언/게시 요약",
      "url": "URL"
    }
  ],
  "cross_domain": [
    {
      "intersection": "AI + Blockchain",
      "topic": "AI Agents on Blockchain",
      "summary": "요약"
    }
  ],
  "weekly_trend": {
    "rising_keywords": ["GPT-5", "AGI"],
    "declining_keywords": ["NFT"]
  },
  "total_sources_checked": 15,
  "collection_time_seconds": 45
}
```

---

## 5단계: 영상 가치 판별 (Video Potential)

각 뉴스에 대해 "이 뉴스가 영상으로 만들 가치가 있는가"를 판별합니다:

### 높음 (High)
- 주요 기업의 제품/서비스 출시 발표
- 기술적 브레이크스루 (SOTA 달성, 새 아키텍처)
- 대중적 관심이 높은 논쟁/사건
- 커뮤니티 시그널이 매우 강함 (HN 300+, Reddit 1000+)
- 시각적으로 보여줄 수 있는 데모/결과물 존재

### 중간 (Medium)
- 업계 트렌드 분석
- 인물 인터뷰/의견
- 기술 비교/리뷰
- 규제/정책 변화

### 낮음 (Low)
- 단순 투자/가격 보도
- 반복적 업데이트 (마이너 패치)
- 출처 불분명/루머
- 지나치게 기술적 (대중 접근 어려움)

---

## 6단계: 커뮤니티 시그널 수집

가능한 경우 WebSearch로 커뮤니티 반응도 함께 수집:

```
- Hacker News: "site:news.ycombinator.com {제목 키워드}" → points 확인
- Reddit: "site:reddit.com {제목 키워드}" → upvotes 확인
- 논문: "site:arxiv.org {제목}" → 인용수 확인
```

---

## 실행 규칙

1. **WebSearch를 적극 활용**: 각 도메인별 최소 5회 이상 검색
2. **공신력 소스 우선**: Tier 1 소스에서 나온 정보를 상위에 배치
3. **중복 제거**: 같은 뉴스가 여러 소스에서 나오면 가장 공신력 높은 소스 1개만 + "N개 매체에서 보도" 표시
4. **한국어 소스 포함**: 각 도메인 검색 시 한국어 쿼리 1회 이상 포함
5. **Top 10 선별**: 수집한 뉴스 중 중요도 + 영상 가치 기준 Top 10만 최종 출력
6. **JSON 형식 필수**: 위의 JSON 스키마를 반드시 준수
7. **날짜 기반**: 기본은 최근 24시간. 키워드 지정 시 최근 7일까지 확장
8. **실행 시간**: 전체 리서치를 3분 이내 완료 목표

---

## `claude -p` 자동화 연동

이 스킬의 결과를 CineBot 파이프라인에 자동 투입하려면:

```bash
# 15분마다 자동 실행
claude -p "/research ai" --output-format json -C /path/to/project

# 결과를 DB에 저장하는 wrapper
python -c "
import subprocess, json, sqlite3
result = subprocess.run(
    ['claude', '-p', '/research ai', '--output-format', 'json'],
    capture_output=True, text=True, timeout=180
)
# JSON 파싱 후 DB 저장
"
```

## 주의사항

- WebSearch 결과가 부족하면 "정보 부족" 표시 (추측/생성 금지)
- 소스 URL은 반드시 실제 접근 가능한 URL만 포함
- 미확인 정보는 "미확인" 태그 부착
- 가격/수치 정보는 반드시 출처와 함께 표시
