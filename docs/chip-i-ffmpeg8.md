# 칩 I — SwiftFFmpeg: 업스트림 정리 · FFmpeg 8.x · VideoToolbox

작성: 2026-10-21 · 브랜치 `claude/ffmpeg-8x-cd71c7` · base `02cfa3c` (= `origin/master`)
커밋 2개: `4e1f286` (8.1.3 버전 수정), `d8807f2` (videotoolbox 디코드 활성화). **푸시·PR 안 함.**

---

## 0. 세 줄 요약

1. **8.x 는 이미 지원된다.** 업스트림이 2025-11-30 에 `38d3da7 "FFmpeg 8.0 support"` 로 끝냈고 포크가 이미 병합해뒀다. 래퍼 소스는 **한 줄도 고칠 필요 없었다** (8.1.3 헤더 대상 타입체크 에러 0 / 경고 0).
2. **그런데 빌드가 아예 안 됐다.** `FFMPEG_VERSION=8.0.0` 인데 FFmpeg 에 `n8.0.0` 태그가 **없다** → 다운로드 404. 8.1.3 으로 고쳤다.
3. **videotoolbox 는 켜면 진짜로 들어온다.** 출하 아티팩트에 대해 런타임 실증 완료
   (`av_hwdevice_ctx_create` → `ENOMEM` 에서 **성공**으로), 크기 비용 **+0.18%**,
   기존 소프트웨어 디코드 경로는 **바이트 단위로 동일**(해시 일치).
   **7/7 슬라이스 빌드 성공 · `swift build` 성공 · 테스트 10/10 통과.**

**단, 플래그 하나 떼는 일이 아니었다.** 켜는 과정에서 네 가지가 딸려 나왔고 전부 처리했다:
`Package.swift` 의 **CoreVideo 링크 누락**(이것 때문에 `swift build` 가 깨졌다 — FX Viewer 도
같이 깨졌을 것), **VT 인코더 3종**이 켜지며 `avcodec_find_encoder(H264)` 가 `nil`→비-`nil` 로
뒤집히는 문제, **VT 필터 3종**이 Metal 링크 의무를 새로 지우는 문제, 그리고
**Mac Catalyst 컴파일 불가**(FFmpeg 쪽 버그). 앞의 셋은 범위를 디코딩으로 좁혀서,
마지막은 그 슬라이스만 꺼서 해결했다.

> ⚠️ 착수 전 브리핑과 실제 상태가 달랐다. 브리핑은 "HEAD = `6c9d3a7`, `FFMPEG_VERSION=7.1.1`" 였는데
> 실제 `origin/master` 는 `02cfa3c` 로, 업스트림 병합과 8.0 버전 범프가 **이미 들어가 있었다**.
> `6c9d3a7` 은 **FX Viewer 서브모듈 핀**의 위치다 — 그게 origin/master 보다 3 커밋 뒤처져 있던 것.

---

## 1. 과제 1 — 업스트림 격차

### 결론: 격차 없음. 병합할 것이 하나도 없다.

```
git rev-list --left-right --count upstream/master...HEAD
  0   18          # 0 behind, 18 ahead
git merge-base --is-ancestor upstream/master HEAD   → true
```

`upstream/master` (`38d3da7`) 는 **HEAD 에 완전히 포함**돼 있다. 병합 권고는 **"할 것 없음"** 이다.
업스트림 자체가 사실상 정지 상태다 — 포크 이후 쌓인 커밋이 3개뿐이고 마지막이 2025-11-30 이다.

흡수된 업스트림 커밋 3개 중 **우리에게 의미 있는 것**:

| 커밋 | 내용 | 우리에게 |
|---|---|---|
| `38d3da7` | FFmpeg 8.0 대응 — 8.x 에서 제거된 상수 3개 삭제, `SwsContext` 포인터 타입 수정 | **8.x 를 가능하게 한 전부.** §3 참조 |
| `ec43788` | 자막 코덱 ID 26개 추가 + **`AVIOContext.size()` 크래시 수정** | 크래시 수정이 FX Viewer 녹화에 직결. §4.2 |
| `754c6c5` | 위 커밋의 컴파일 에러 정정 | 기계적 |

### 우리 포크가 벌어진 지점 — 사용자 말이 거의 맞다

```
git diff upstream/master...HEAD --stat
 .gitignore                        |   3 +
 .swiftpm/…/xcschemes (4개)        |   8 +-
 Package.swift                     |  42 ++++-
 README.md                         |   2 +-
 Scripts/build.sh                  |  91 +++++++---
 Scripts/build_framework.sh        | 184 ++++++++++++++++++---
 Sources/CFFmpeg/dummy.c           |  10 ++
```

**`Sources/SwiftFFmpeg/` 는 단 한 글자도 안 건드렸다.** 병합 난이도는 구조적으로 0 이다.
유일한 Sources 변경인 `dummy.c` 는 신규 파일 10줄(빈 함수 하나)로, SwiftPM 이 C 타깃에
소스 파일 1개를 요구해서 넣은 것이다. 충돌 가능성 없음.

---

## 2. 과제 2 — FFmpeg 8.x

### 2.1 버전 선택: `8.1.3`

FFmpeg 8.x 태그 전수 확인 (`git ls-remote --tags`):

```
n8.0  n8.0.1  n8.0.2  n8.0.3  n8.1  n8.1.1  n8.1.2  n8.1.3    (+ n8.1-dev, n8.2-dev)
```

**`n8.0.0` 은 존재하지 않는다.** 그래서 기존 `02cfa3c` 의 설정은 빌드 불능이었다:

```
curl …/tar.gz/n8.0.0  → HTTP 404     ← 기존 (깨짐)
curl …/tar.gz/n8.0.3  → HTTP 200
curl …/tar.gz/n8.1.3  → HTTP 200     ← 채택
```

`ffmpeg.org/releases/` 의 8.x 공식 릴리스 목록과도 교차 확인했다 (8.0 → 8.1.3 까지 8개, `8.0.0` 없음).
**8.1.3 이 8.x 최신 안정본**이라 이것을 택했다.

> 참고: 현재 FFmpeg 최신은 **9.0.2** 다. 9.x 로의 이동은 이번 범위 밖이고, 8.1 → 9.0 은
> 또 한 번의 API 제거 라운드를 포함하므로 별도 과제로 다뤄야 한다.

### 2.2 API 파괴 전수 확인 — 결과: 래퍼 수정 불필요

`Sources/SwiftFFmpeg/*.swift` 와 `Sources/CFFmpeg/*.h` 에서 FFmpeg 식별자 **981개**를 추출해
8.1.3 공개 헤더 전체(218,540줄)와 대조했다. 헤더에 없는 것 67개 중 **실제 코드 참조는 2개**뿐이고
(나머지는 래퍼 자신의 Swift 타입명·헤더 가드·주석), 그 2개는 **죽은 코드**다:

```swift
// Sources/SwiftFFmpeg/AVFrameSideData.swift:90
#if FF_API_FRAME_QP                                    // ← 한 번도 정의되지 않는다
  public static let qpTableProperties = AV_FRAME_DATA_QP_TABLE_PROPERTIES
  public static let qpTableData       = AV_FRAME_DATA_QP_TABLE_DATA
#endif
```

`FF_API_FRAME_QP` 는 **Swift 컴파일 조건**이지 C 매크로가 아니다. `Package.swift` 에도
`swiftSettings` 에도 정의가 없다 (`grep` 전수 0건). 따라서 FFmpeg 8 이 `AV_FRAME_DATA_QP_TABLE_*` 를
제거했어도 **이 블록은 컴파일되지 않는다**. 손댈 필요 없다.

**실증 — 8.1.3 헤더 대상 타입체크:**

```
swiftc -typecheck -module-name SwiftFFmpeg Sources/SwiftFFmpeg/*.swift \
  -Xcc -fmodule-map-file=Sources/CFFmpeg/module.modulemap \
  -Xcc -ISources/CFFmpeg -Xcc -I<ffmpeg-8.1.3>/include

  → errors: 0   warnings: 0
```

### 2.3 8.x 에서 실제로 제거된 것 (업스트림이 이미 대응함)

8.1.3 헤더에 없음을 직접 확인:

| C 상수 | 8.1.3 | 래퍼 공개 API | 대응 |
|---|---|---|---|
| `AV_CODEC_CAP_SUBFRAMES` | 제거됨 | `AVCodec.Cap.subframes` | `38d3da7` 에서 삭제 |
| `AVFMT_ALLOW_FLUSH` | 제거됨 | `AVOutputFormat.Flag.allowFlush` | `38d3da7` 에서 삭제 |
| `AVFMT_FLAG_SHORTEST` | 제거됨 | `AVFormatContext.Flag.shortest` | `38d3da7` 에서 삭제 |
| `AV_CODEC_CAP_TRUNCATED` | 제거됨 | (래퍼가 노출 안 함) | — |

`SWS_*` 플래그는 8.x 에서 `#define int` → **enum (`SwsFlags`)** 으로 바뀌었다. 업스트림이
`Int32(SWS_BILINEAR.rawValue)` 식으로 대응했고 **값은 불변**이라 동작 차이 없다.

---

## 3. ⭐ FX Viewer 가 영향받는 공개 API 변경 — 가장 중요한 절

FX Viewer 핀 `6c9d3a7` → 이 브랜치 사이의 `Sources/` 변경 전부를 검토하고,
FX Viewer(`Shared/Streaming/Provider/RTSP/`, `Shared/Recording/`, 그리고 앱 전체)에서
실사용 여부를 역으로 확인했다.

### 3.1 제거된 공개 API 3개 — **FX Viewer 영향 없음 (사용 0건)**

| 제거된 심볼 | 앱 전체 grep |
|---|---|
| `AVCodec.Cap.subframes` | **0건** |
| `AVOutputFormat.Flag.allowFlush` | **0건** |
| `AVFormatContext.Flag.shortest` | **0건** |

`AVCodec.Cap` / `AVOutputFormat.Flag` / `AVFormatContext.Flag` **타입 자체를 FX Viewer 가
전혀 쓰지 않는다** (각 0건). 즉 소스 호환성 파괴는 **없다**.

### 3.2 조용한 동작 변화 2개 — 둘 다 FX Viewer 에 닿는다

**(a) `AVIOContext.size()` — 크래시 → 정상 동작 (`ec43788`)**

```swift
-    try throwIfFail(Int32(ret))            // 2 GiB 초과 시 Swift 런타임 트랩 (프로세스 사망)
+    try throwIfFail(Int32(clamping: ret))  // 클램프 → 올바른 Int64 반환
```

`avio_size()` 는 `Int64` 를 돌려준다. 기존 코드는 이를 `Int32(_:)` 로 변환했는데,
**파일이 `Int32.max`(2,147,483,647 B ≈ 2.0 GiB)를 넘으면 Swift 가 트랩해 앱이 죽는다.**
이건 에러 throw 가 아니라 **복구 불가능한 크래시**다.

→ FX Viewer `Shared/Recording/` 는 장시간 녹화를 만든다. **2 GiB 넘는 녹화 파일에서
`size()` 를 부르면 현재 핀(`6c9d3a7`)에서는 앱이 죽는다.** 핀을 옮기면 이게 고쳐진다.
**이번 변경에서 FX Viewer 가 얻는 가장 실질적인 이득이다.**
(현재 `size()` 직접 호출은 확인되지 않았으나, 핀 이동으로 잠재 크래시가 제거된다.)

**(b) `AVHWDeviceType.supportedDeviceTypes()` — 빈 배열 → `["videotoolbox"]`**

`VideoDecoderProbe.swift:62` 가 이걸 쓴다:

```swift
libraryHWDeviceTypes = AVHWDeviceType.supportedDeviceTypes().map(\.description)
```

내부는 `av_hwdevice_iterate_types()` 다. videotoolbox 를 켜면 **`[]` → `["videotoolbox"]`** 로 바뀐다.
`VideoDecoderProbe` 는 **진단 전용**(보고만 함)이라 동작 파괴는 아니지만,
이 값으로 분기하는 코드가 생기면 의미가 달라진다. 기대값을 하드코딩한 테스트가 있으면 깨진다.

### 3.3 🔴 `AVCodec.findEncoderById(.H264)` 가 `nil` → **비-nil** 로 바뀔 뻔했다 (막았다)

적대적 피어 리뷰가 잡은 건이고, **내가 놓쳤던 것**이다. `--disable-videotoolbox` 를 떼면
디코더 hwaccel 만 들어오는 게 아니라 **VideoToolbox 인코더 3종**
(`h264_videotoolbox`, `hevc_videotoolbox`, `prores_videotoolbox`)도 같이 켜진다.

이 빌드에는 **소프트웨어 H.264/HEVC 인코더가 없다**(libx264 미포함). 그래서 실측하면:

| | `--disable-videotoolbox` | 플래그만 제거 |
|---|---|---|
| `avcodec_find_encoder(H264)` | **NULL** | **`h264_videotoolbox`** |
| `avcodec_find_encoder(HEVC)` | **NULL** | **`hevc_videotoolbox`** |

즉 래퍼의 `AVCodec.findEncoderById(.H264)` 반환값이 **`nil` → 비-`nil`** 로 뒤집힌다.
코덱 ID 로만 인코더를 찾는 호출자는 **하드웨어 인코딩을 요청한 적도 없는데** 거기에
들어가게 되고, `nil` 을 보고 폴백하던 경로가 조용히 사라진다.

**대응: 디코딩으로 범위를 한정했다.** 과제는 하드웨어 **디코딩**이었으므로,
인코더 3종은 명시적으로 껐다:

```bash
CONFIGURE_HWACCEL_OPTIONS="--disable-encoder=h264_videotoolbox,hevc_videotoolbox,prores_videotoolbox"
```

하드웨어 **인코딩**을 원하면 이 한 줄만 지우면 된다 (`build.sh` 주석에 적어뒀다).
그건 녹화 경로에 별도 이득이 될 수 있으나, 이번 과제 범위가 아니고 위처럼 조용한
동작 변화를 동반하므로 **의도적으로 선택해야 하는 일**이다.

**FX Viewer 영향: 없다.** 앱 전체에서 `findEncoder*` 호출이 **0건**이고
(`SwiftFFmpeg/Sources/Examples/` 의 2건은 래퍼 예제), `RecordingSession.swift:172-207` 은
`addStream()` + `codecParameters` 직접 설정 + `extradata` 복사 방식의 **스트림 카피(remux)**
라서 인코더를 아예 거치지 않는다.

### 3.4 추가된 API — 비파괴

자막 코덱 ID 26개(`AVCodecID.SUBRIP`, `.WEBVTT`, `.ASS` …) 추가. 순수 가산.

### 3.5 내부 변경 — 공개 API 아님

`SwsContext.native` 타입이 `OpaquePointer` → `UnsafeMutablePointer<CFFmpeg.SwsContext>` 로 바뀌었다.
`public` 이 아닌 **internal** 프로퍼티라 모듈 밖에서 안 보인다. FX Viewer 영향 없음.

### 3.6 🔴 빌드 요구사항 변화 — `Package.swift` 에 **CoreVideo** 가 필요해졌다

API 변경은 아니지만 **FX Viewer 빌드를 깨뜨렸을** 항목이라 여기 적는다.

VideoToolbox 를 켜면 `libavcodec/videotoolbox.o` 와 `libavutil/hwcontext_videotoolbox.o`
가 `kCVPixelBufferWidthKey`, `kCVPixelBufferIOSurfacePropertiesKey`,
`kCVImageBufferYCbCrMatrix_ITU_R_709_2` 같은 **CoreVideo 심볼**을 참조한다.
기존에는 아무도 참조하지 않던 것들이다.

그런데 `Package.swift` 의 `linkerSettings` 에는 CoreGraphics · CoreAudio · CoreImage ·
VideoToolbox · Foundation · CoreMedia · AudioToolbox · AVFoundation 은 있어도
**CoreVideo 가 없었다.** 결과:

```
Undefined symbols for architecture arm64:
  "_kCVPixelBufferWidthKey", referenced from:
      _videotoolbox_start in libavcodec[arm64](videotoolbox.o)
ld: symbol(s) not found for architecture arm64
```

**FX Viewer 도 같이 깨졌을 것이다** — `project.pbxproj` 가 SwiftFFmpeg 을
SwiftPM product(`productRef`)로 참조하므로 이 `linkerSettings` 가 그대로 적용된다.

→ `Package.swift` 에 `.linkedFramework("CoreVideo")` 추가. **커밋 `d8807f2` 에 포함.**

(그 다음엔 `MTLCreateSystemDefaultDevice` 때문에 또 깨졌는데, 그건 Metal 을 새로
링크하게 만드는 대신 **VT 필터를 꺼서** 해결했다 — §4.6(a).)

### 3.7 FX Viewer 가 실제로 쓰는 SwiftFFmpeg API (전수)

`AVCodec.findDecoderById` · `AVError.outOfMemory` · `AVHWDeviceType.supportedDeviceTypes` ·
`AVIOContext.Flag` · `AVLog.level` · `AVPacket.Flag` · `AVPixelFormat.BGRA` · `SwsContext.Flag`
(+ `AVFrame`, `AVPacket`, `AVImage`, `AVCodecContext`, `AVFormatContext`, `AVStream`, `AVRational` 인스턴스 API)

**이 중 8.x 로 인해 시그니처·의미가 바뀐 것은 없다.**

---

## 4. 과제 3 — VideoToolbox

### 4.0 어느 플랫폼에서 하드웨어 디코드가 되는가 (슬라이스별 표)

`Scripts/build.sh` 에서 `--disable-videotoolbox` 가 들어가는 곳은 **단 한 군데,
62번 줄의 `maccatalyst` 분기뿐**이다. 나머지는 전부 활성이다.

| 슬라이스 | VideoToolbox 디코드 | VT 인코더 | 비고 |
|---|:--:|:--:|---|
| `iphoneos-arm64` (실기) | **✅ 있음** | ❌ 끔 | FX Viewer 출하 타깃 |
| `iphonesimulator-arm64` | **✅ 있음** | ❌ 끔 | FX Viewer 개발 타깃 |
| `iphonesimulator-x86_64` | **✅ 있음** | ❌ 끔 | |
| `macosx-arm64` | **✅ 있음** | ❌ 끔 | FX Viewer macOS |
| `macosx-x86_64` | **✅ 있음** | ❌ 끔 | |
| `maccatalyst-arm64` | **❌ 없음** | ❌ 끔 | 컴파일 불가 — §4.5 |
| `maccatalyst-x86_64` | **❌ 없음** | ❌ 끔 | 컴파일 불가 — §4.5 |

**즉 시뮬레이터도 macOS 도 하드웨어 디코드가 된다. 빠지는 건 Mac Catalyst 뿐이고,
FX Viewer 는 Catalyst 를 빌드하지 않는다**(`SUPPORTS_MACCATALYST = NO`,
`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`). FX Viewer 가 쓰는 범위에서는
**손실이 없다.**

> 혼동 주의: `TARGET_OS_IPHONE` 은 `build.sh` 의 분기 조건이 **아니다**. 그건 FFmpeg
> C 소스(`libavcodec/videotoolbox.c`) 안의 매크로이고, `build.sh` 에는 Catalyst 를
> 제외한 **이유를 설명하는 주석**(54번 줄)으로만 등장한다. 플랫폼 선택은 전적으로
> `$PLATFORM` 문자열 분기로 이뤄진다.

### 4.1 검증 방법

플래그 **하나만** 다른 macosx/arm64 FFmpeg 8.1.3 빌드 2벌을 만들고, 두 바이너리에 대해
동일한 C 프로브를 **실제로 실행**했다. 심볼 존재가 아니라 **반환값**으로 판정했다.

### 4.2 결과

| 판정 기준 | `--disable-videotoolbox` | 플래그 제거 |
|---|---|---|
| `av_hwdevice_iterate_types()` | **0개** | **`videotoolbox`** (1개) |
| `avcodec_get_hw_config(h264, 0)` | **NULL** | `pix_fmt=videotoolbox_vld`<br>`device_type=videotoolbox`<br>`methods=0xb` |
| `av_hwdevice_ctx_create(VIDEOTOOLBOX)` | **`-12` ENOMEM** | **`0` (성공)** |
| `nm -a libavcodec \| grep -ci videotoolbox` | **0** | **94** |
| `nm -a libavutil \| grep -ci videotoolbox` | **0** | **11** |
| **하드웨어 디코드 가용** | **NO** | **✅ YES** |

최종 형상(인코더 비활성화 + Catalyst 예외 포함)에서도 재확인했다 — 하드웨어 디코드는
**그대로 YES**이고, `avcodec_find_encoder(H264/HEVC)` 는 **NULL 로 복귀**했으며,
소프트웨어 디코드 해시는 여전히 `940198ebf9b29935` 로 동일하다.

`-12 ENOMEM` 은 칩 G 가 출하 바이너리에서 관측한 값과 **정확히 일치**한다 — 독립 재현됐다.

### 4.3 ⚠️ 함정 실증

```
av_hwdevice_find_type_by_name("videotoolbox") = 6 (non-NONE)   ← 두 빌드 모두 동일
```

**백엔드가 0개인 빌드에서도 6 을 반환한다.** enum↔문자열 정적 테이블이라 어떤 빌드에서도
이름을 안다. 이 함수나 `strings` 로 가용성을 판단하면 100% 속는다.
가용성 판정은 **반드시** `avcodec_get_hw_config()` 또는 `av_hwdevice_ctx_create()` 반환값으로.

### 4.4 바이너리 크기 비용 — +0.18%

macosx/arm64 정적 아카이브 7개, **실제 출하 형상** 기준
(videotoolbox 디코드 ON, 인코더 3종 OFF, VT 필터 3종 OFF):

| 라이브러리 | 기존 (B) | 최종 (B) | 증가 (B) | % |
|---|---:|---:|---:|---:|
| libavcodec | 17,642,640 | 17,675,296 | **+32,656** | +0.19% |
| libavutil | 1,004,808 | 1,026,552 | **+21,744** | +2.16% |
| libavfilter | 5,708,992 | 5,709,088 | +96 | ~0% |
| libavdevice | 75,696 | 75,792 | +96 | +0.13% |
| libavformat | 4,595,944 | 4,596,040 | +96 | ~0% |
| libswresample | 135,136 | 135,232 | +96 | +0.07% |
| libswscale | 1,416,712 | 1,416,792 | +80 | +0.01% |
| **합계** | **30,579,928** | **30,634,792** | **+54,864** | **+0.18%** |

**29.16 MiB → 29.22 MiB (+0.052 MiB).**

범위를 좁힌 효과가 크다 — 인코더·필터까지 그대로 켰다면 +152,144 B (+0.50%) 였다.
인코더 비활성화가 libavcodec 에서 64,120 B, 필터 비활성화가 libavfilter 에서
33,896 B 를 되돌려준다.

> 이는 **정적 아카이브 측정값일 뿐**이고, 앱 바이너리 증가분이 아니다.
> (적대적 리뷰 지적 반영) 처음에 "런타임에 hwaccel 을 쓰기 시작하면 증가분이 커진다"고
> 썼는데 **틀렸다**. `libavcodec/allcodecs.c` 의 코덱 레지스트리와 `h264dec.c` 의 hwaccel
> 참조는 **정적**이라, 앱이 하드웨어 디코드를 한 번도 요청하지 않아도 해당 오브젝트는
> 링크된다. 런타임 사용 여부는 링크 여부를 결정하지 않는다.
> 실제 앱 증가분을 알려면 링커 맵으로 따로 재야 한다 — 이번에 측정하지 않았다.

### 4.5 🔴 Mac Catalyst 는 videotoolbox 를 켜면 **컴파일이 깨진다** — 그 슬라이스만 끔

플래그를 떼고 7슬라이스 전체 빌드를 돌리자 **maccatalyst 에서만** 실패했다:

```
libavcodec/videotoolbox.c:821:45: error:
  'kCVPixelBufferOpenGLESCompatibilityKey' is unavailable: not available on macCatalyst
```

**원인은 FFmpeg 쪽 버그다.** `libavcodec/videotoolbox.c:820-824` 의 분기가 이렇다:

```c
#if TARGET_OS_IPHONE
    CFDictionarySetValue(buffer_attributes, kCVPixelBufferOpenGLESCompatibilityKey, kCFBooleanTrue);
#else
    CFDictionarySetValue(buffer_attributes, kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey, kCFBooleanTrue);
#endif
```

Mac Catalyst 는 `TARGET_OS_IPHONE == 1` 이라 **iOS 분기를 탄다**. 그런데 SDK 는 그 심볼을
`API_UNAVAILABLE(macCatalyst)` 로 막아놨다. 올바른 가드는
`#if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST` 여야 한다.

**대응: maccatalyst 슬라이스에만 `--disable-videotoolbox` 를 유지했다.**

```bash
# Scripts/build.sh, maccatalyst 분기
CONFIGURE_HWACCEL_OPTIONS="--disable-videotoolbox"
```

**왜 벤더 소스를 패치하지 않았나:** `#else` 분기가 쓰는
`kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey` 는 SDK 에서
`API_AVAILABLE(macosx(10.6)) __IOS_PROHIBITED` 라서 Catalyst 에서 쓸 수 있는지가
불확실하다. 추측으로 벤더 트리를 고치느니, 안 쓰는 슬라이스에서 끄는 쪽이 확실하다.

**비용은 0 이다 — FX Viewer 는 Catalyst 를 빌드하지 않는다:**

```
SUPPORTS_MACCATALYST = NO        (×2, FX Viewer.xcodeproj)
SUPPORTED_PLATFORMS  = "iphoneos iphonesimulator"
```

> ⚠️ **다만 이건 슬라이스 간 비대칭이다.** iphoneos / iphonesimulator / macosx 는 HW 디코드가
> 되고 **maccatalyst 만 안 된다**. 나중에 Catalyst 타깃을 켜는 사람은 거기서만 `ctx_create` 가
> `ENOMEM` 을 돌려받고 영문을 모를 수 있다. 그때는 위 `#if` 가드를 패치하는 쪽으로 가야 한다.

곁가지로 `CONFIGURE_TLS_OPTIONS` 가 루프 반복 간에 **값이 새는** 선존 버그를 발견했다
(`iphoneos` 에서 `--enable-securetransport` 로 설정된 뒤 `iphonesimulator`·`macosx`
반복에서 초기화되지 않아 그대로 이월된다). 기존 동작을 바꾸지 않으려 그건 손대지 않았고,
내가 추가한 `CONFIGURE_HWACCEL_OPTIONS` 만 매 반복 초기화하도록 했다. **별도 수정 후보다.**

### 4.6 ✅ 소프트웨어 디코드 경로는 **바이트 단위로 동일**하다

"videotoolbox 를 켜면 hwaccel 을 요청하지 않은 기존 경로가 조용히 달라지지 않나?" 를
실측했다. 동일한 1080p25 H.264 클립(100프레임)을 **일반 소비자와 똑같이**
(`hw_device_ctx` 미설정, 커스텀 `get_format` 없음, `thread_count=1`) 디코드하고
전 프레임 픽셀을 FNV-1a 로 해싱했다:

| | `--disable-videotoolbox` | videotoolbox 활성 |
|---|---|---|
| decoder | `h264` | `h264` |
| first pix_fmt | `yuv420p` | `yuv420p` |
| hw 프레임 수 | 0 | **0** |
| `hw_device_ctx` | null | **null** |
| 전 프레임 FNV-1a64 | `940198ebf9b29935` | **`940198ebf9b29935`** |

**해시가 같다.** 기본 설정(커스텀 `get_format` 없음)으로 H.264 를 소프트웨어 디코드하는
경로는 출력이 **바이트 단위로 동일**하다.

#### ⚠️ 다만 "전혀 안 바뀐다"고 말하면 과장이다 — 적대적 리뷰가 좁혀준 범위

이 해시 테스트가 **덮지 못하는** 변화가 둘 남아 있다. 둘 다 컴파일은 멀쩡히 되고
테스트에도 안 잡히는 종류다.

**(a) 필터 3종 — 발견했고, 껐다.** VideoToolbox 를 켜면 `transpose_vt`, `scale_vt`,
`yadif_videotoolbox` 가 같이 등록된다(`libavfilter/allfilters.c`). 래퍼의
`AVFilter`(`AVFilter.swift:55,103`) 로 필터를 **열거하거나 이름으로 찾는** 코드는
목록이 달라진 걸 본다. 디코드 해시로는 절대 안 잡힌다.

게다가 `yadif_videotoolbox` 는 **`MTLCreateSystemDefaultDevice` 를 끌어온다** — 실제로
`swift build` 가 이것 때문에 링크 실패했다. 소비자 전원에게 **Metal 링크 의무**를
새로 지우는 셈이다. 디코딩에 필요 없으므로 **비활성화했다**:

```bash
--disable-filter=yadif_videotoolbox,transpose_vt,scale_vt
```

출하 아카이브에서 확인: `yadif_videotoolbox` 0건, `transpose_vt` 0건,
`MTLCreateSystemDefaultDevice` 0건. **필터 열거 변화도 Metal 의존도 남지 않았다.**

**(b) `get_format` 후보 목록에 하드웨어 포맷이 추가된다.**
`h264_slice.c` 가 후보 배열에 `AV_PIX_FMT_VIDEOTOOLBOX` 를 끼워 넣고,
`proresdec.c` 는 전에는 소프트웨어 포맷을 직접 대입하던 자리에서 **이제 `ff_get_format`
을 호출**한다. 즉:

- **커스텀 `get_format` 콜백을 단 호출자**가 "후보 배열의 첫 항목을 고른다" 식이면,
  하드웨어 디바이스를 설정한 적이 없는데도 **하드웨어 포맷을 고를 수 있다.**
- ProRes 를 소프트웨어로 디코드하던 호출자는 전에 **불리지 않던 콜백이 불리기 시작**한다.

→ **FX Viewer 영향 없음**: 커스텀 `get_format`/`GetFormatHandler` 사용 **0건**,
ProRes 디코드 **0건**. 그래서 §4.6 의 해시 동일성이 FX Viewer 에 대해서는 충분하다.

**정확한 주장은 이것이다:** 기본 `get_format` 구성으로 H.264 를 소프트웨어 디코드하는
경로는 검증된 범위에서 **바이트 단위 동일**하다. 필터 열거 변화는 **껐으므로 없다**.
남는 유일한 라이브러리 레벨 변화는 **`get_format` 후보 목록**이고, 이건 커스텀 콜백을
단 호출자에게만 보인다 — FX Viewer 는 해당 없음.

### 4.7 이걸 켠다고 바로 빨라지지는 않는다

**가용해질 뿐, 자동으로 쓰이지 않는다.** 앱 쪽 작업이 따로 필요하다:

- 하드웨어 디코드 프레임은 `format == AV_PIX_FMT_VIDEOTOOLBOX` 인 **불투명 핸들**이다.
  CPU 평면 포인터(`frame->data[0]` 등)가 바로 쓰이지 않으므로, `av_hwframe_transfer_data`
  로 내리거나 바닥의 `CVPixelBuffer` 를 직접 다뤄야 한다. FX Viewer 의
  **렌더러 · AI 전처리 · 녹화** 세 경로가 전부 CPU 평면 YUV420P 를 가정하므로 손봐야 한다.
- 다만 **"VideoToolbox 는 NV12/BGRA 뿐"이라는 말은 사실이 아니다.** 적대적 리뷰가 이걸
  짚었고 소스에서 확인했다 — `libavutil/hwcontext_videotoolbox.c:48-70` 의 매핑 표에는
  `kCVPixelFormatType_420YpCbCr8Planar → AV_PIX_FMT_YUV420P` 가 **들어 있다**
  (그 밖에 UYVY422 · BGRA · NV12 · AYUV · P010 · NV16 · P210). 즉 `CVPixelBuffer` 의
  레이아웃은 **구성 가능**하고, 평면 YUV420P 로 받는 경로도 원리적으로 열려 있다.
  통합 전략을 NV12 전제로 미리 좁히지 말 것.
- CPU 로 내리는 비용이 하드웨어 디코드 이득을 **상쇄하는지는 측정하지 않았다.**
  워크로드에 따라 다르며, 이 리포트는 그것을 주장하지 않는다.

→ 이 커밋은 **전제 조건**이다. 실제 이득(칩 G 가 호스트에서 측정한 디코드 CPU −79%)을
보려면 앱 쪽 hwaccel 통합이 필요하다.

---

## 5. 빌드 / 테스트 결과

전체 결과는 **§7** 에 모아뒀다. 요약: 7/7 슬라이스 빌드 성공, `swift build` 성공,
테스트 10/10 통과, 출하 아티팩트 런타임 검증 통과.
래퍼 타입체크(8.1.3 헤더 대상)는 **에러 0 / 경고 0**.

---

## 5.5 적대적 피어 리뷰 (codex-peer, reviewer) — 2라운드

**1라운드**가 지적한 4건 중 **2건이 내 실수**였고 고쳤다:

| # | 지적 | 내 대응 |
|---|---|---|
| F1 **high** | 플래그 제거가 디코더뿐 아니라 **VT 인코더 3종**도 켜서 `avcodec_find_encoder(H264)` 가 `nil`→비-`nil` 로 뒤집힌다 | **맞다. 내가 놓쳤다.** 실측 확인 후 인코더 3종을 명시적으로 비활성화 (§3.3) |
| F2 medium | maccatalyst 수정이 커밋에 안 들어가 있다 | 커밋에 포함시킴 (`d8807f2` 로 amend) |
| F3 medium | "VT 출력은 NV12/BGRA 뿐"은 과장 — `hwcontext_videotoolbox.c` 는 YUV420P 도 매핑한다 | **맞다.** 소스 확인 후 §4.7 정정 |
| F4 low | "런타임에 써야 오브젝트가 링크된다"는 틀렸다 — 레지스트리 참조는 정적이다 | **맞다.** §4.4 주석 정정 |

**2라운드**(최종 형상 대상)에서 확인된 것:

- ✅ "FFmpeg 8.1.3 에 Swift 소스 변경 불필요" — **독립 확인됨**
- ✅ 인코더 3종 비활성화로 **인코더 탐색 변화는 완전히 닫혔다**. 추가로 뒤집히는
  코덱 ID **없음**
- ✅ `AVIOContext.size()` 의 `Int32(clamping:)` 은 **진짜 음수 AVERROR 를 삼키지 않는다**
  (모든 `AVERROR` 태그 값이 `Int32.min` 안쪽이라 클램프 대상이 아니다)
- ⚠️ 남은 2건(필터 열거, `get_format` 후보) → §4.6 에 명시하고 FX Viewer 영향 0 확인

> 리뷰 2회 모두 `workspace_drift` 로 끝났다 — 1회차는 동시 실행 중이던 빌드가,
> 2회차는 내가 리뷰 도중 리포트를 편집한 탓이다. 내용은 정상 산출됐고 위에 반영했지만,
> 하니스가 "깨끗한 트리에서 돌린 리뷰"로 서명해주지는 않았다. **피어 출력은 증거이지
> 승인이 아니다** — 위 항목은 전부 내가 소스·실측으로 재확인한 것만 적었다.

---

## 6. 📌 서브모듈 핀 — 옮길 SHA와 **그것만으로는 부족한 이유**

### 옮길 SHA

```
claude/ffmpeg-8x-cd71c7   d8807f2   ← 빌드 스크립트 변경 전부가 여기까지 들어있다
```

현재 핀: `6c9d3a7` → 이동 후: **`d8807f2`** (문서 커밋은 코드에 영향 없음).

### ⚠️ 핀 이동만으로는 **새 바이너리가 들어오지 않는다**

FX Viewer 의 `project.pbxproj` 는 이렇게 참조한다:

```
$(SRCROOT)/SwiftFFmpeg/Scripts/output/xcframework/libavcodec.xcframework
$(SRCROOT)/SwiftFFmpeg/Scripts/output/include
```

그런데 `Scripts/output/` 은 SwiftFFmpeg 의 **`.gitignore` 대상**이다
(`.gitignore:71` 의 `scripts/*` 가 `core.ignorecase=true` 인 macOS 에서 `Scripts/*` 에 매칭).

**즉 xcframework 는 git 에 없다. 각자 로컬에서 빌드한 산출물이다.**

따라서 필요한 절차는:

```bash
cd ~/Sources/SMI/fx-viewer-ios/SwiftFFmpeg
git checkout d8807f2
cd Scripts && ./build.sh      # ← 이걸 반드시 다시 돌려야 8.1.3 + videotoolbox 가 들어온다
```

핀만 옮기고 재빌드를 안 하면 **Swift 소스만 새것이고 FFmpeg 바이너리는 옛날 7.x
(videotoolbox 없는)** 상태로 섞인다. 조용히 어긋나는 조합이니 주의.

### 커밋된 `xcframework/*.zip` 에 대해 — **갱신하지 않았다**

조사 결과 이 디렉터리는 **죽은 유물**이다:

- 전부 **2020-08-06** 단일 커밋 `3eea7d8 "add precompiled xcframework"` 이후 한 번도 갱신 안 됨
- 슬라이스가 **`macos-x86_64` 하나뿐** (iOS 없음, arm64 없음)
- `Package.swift` 가 참조하지 않는다 (`Scripts/output/xcframework/` 를 본다)
- FX Viewer `project.pbxproj` 에서 참조 **0건**

즉 "레포 관행이 zip 을 커밋해둔다"는 전제는 **업스트림의 2020년 흔적**이지 현재 포크의
배포 경로가 아니다. 4플랫폼 8.1.3 zip 을 새로 커밋하면 수백 MB 를 추가하면서
**아무도 읽지 않는** 파일이 된다. → **커밋하지 않았다. 판단을 요청한다** (§8).

---

## 7. 전 플랫폼 빌드 결과 — **7/7 성공**

`Scripts/build.sh` 전체 실행, 종료 코드 **0**, `The compilation of FFmpeg is completed.`

| 슬라이스 | FFmpeg 빌드 | libavcodec VT 심볼 |
|---|:--:|---:|
| `iphoneos-arm64` | ✅ | 80 |
| `iphonesimulator-arm64` | ✅ | 80 |
| `iphonesimulator-x86_64` | ✅ | 80 |
| `macosx-arm64` | ✅ | 80 |
| `macosx-x86_64` | ✅ | 80 |
| `maccatalyst-arm64` | ✅ | 0 (의도적, §4.5) |
| `maccatalyst-x86_64` | ✅ | 0 (의도적, §4.5) |

생성된 xcframework 7개(`libav{codec,device,filter,format,util}`, `libsw{resample,scale}`),
각 5슬라이스(`ios-arm64`, `ios-arm64_x86_64-simulator`, `macos-arm64_x86_64`,
`maccatalyst-arm64_x86_64`, `ios-arm64_x86_64-maccatalyst`).

### SwiftFFmpeg 패키지

```
swift build  →  Build complete!
swift test   →  Executed 10 tests, with 0 failures
```

> ⚠️ `swift build` 는 처음에 **실패했다.** VideoToolbox 를 켜자
> `kCVPixelBuffer*` / `kCVImageBufferYCbCrMatrix_*` 심볼이 필요해졌는데
> `Package.swift` 가 **CoreVideo 를 링크하지 않고 있었다**. 그 다음엔
> `MTLCreateSystemDefaultDevice`(yadif_videotoolbox 필터) 때문에 또 실패했다.
> 전자는 `Package.swift` 에 `.linkedFramework("CoreVideo")` 추가로,
> 후자는 VT 필터 비활성화로 해결했다. **둘 다 커밋에 포함돼 있다.**
> FX Viewer 는 SwiftPM product 로 이 패키지를 참조하므로
> (`project.pbxproj` 의 `productRef`), CoreVideo 누락은 **FX Viewer 링크도
> 깨뜨렸을 것**이다.

### 최종 런타임 검증 (출하 `macosx-arm64` 아티팩트 대상)

| 항목 | 결과 |
|---|---|
| `av_hwdevice_iterate_types()` | `videotoolbox` |
| `avcodec_get_hw_config(h264,0)` | `videotoolbox_vld`, `methods=0xb` |
| `av_hwdevice_ctx_create(VIDEOTOOLBOX)` | **0 (성공)** |
| `avcodec_find_encoder(H264/HEVC)` | **NULL** (기존과 동일) |
| SW 디코드 전 프레임 해시 | `940198ebf9b29935` (기존과 동일) |
| `yadif_videotoolbox` / `MTLCreateSystemDefaultDevice` | **0건** |

## 8. 사용자 결정이 필요한 것

1. **`xcframework/*.zip` 을 갱신할까? → 안 했다. 확인 부탁한다.**
   §6 근거로 불필요하다고 판단했다: 2020년 유물이고, `Package.swift` 도 FX Viewer 도
   참조하지 않으며(참조 0건), 실제 경로는 `Scripts/output/xcframework/`(gitignore 대상)다.
   **용량도 문제다 — 이번에 생성된 xcframework 전체가 283 MB** 이고
   그중 `libavcodec.xcframework` 하나가 163 MB 다. 압축해도 레포에 100 MB 단위를
   얹는 셈이고 GitHub 파일 크기 제한(100 MB)에도 걸린다. 원하면 말해달라.
2. **`.gitignore` 의 `docs/`** — 이 리포트는 `git add -f` 로 강제 추가했다.
   `docs/` 는 jazzy 생성물용 무시 규칙인데 손으로 쓴 문서까지 삼킨다. 예외 규칙
   (`!docs/chip-*.md`)을 넣을지는 사용자 판단.
3. **9.x 이동** — 현재 FFmpeg 최신은 9.0.2 다. 별도 과제로 다룰지.
