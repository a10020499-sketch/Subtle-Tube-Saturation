# MATLAB R2026a 專案規格書 V2.2
## FabFilter Saturn 2 Subtle Tube / Subtle Saturation Multiband Colorizer — Loop Engineering 執行規格書

Loop Engineering 自主迭代協議 + 技術規格 + GitHub 版本控制（含全新專案建置）

> ## 🎯 專案目標宣告（Primary / Secondary Goal）— 全文件最優先原則
> **Primary Goal**：做出一個真正好聽、會願意掛在 Master Bus / Mix Bus / Vocal Bus 上的 Tube Saturator（以及對應風味的 Subtle Saturation 音色）。
> **Secondary Goal**：透過黑箱量測盡可能逼近 FabFilter Saturn 2 Subtle Tube / Subtle Saturation 的實際行為，作為建立可信技術基線的手段，**不是專案終點**。
>
> 這條宣告會直接改變 EVALUATE 步驟的判斷邏輯：當 Phase A（見下）達到「足夠接近」的基線後，**禁止**繼續為了把 THD_error 從 0.3 dB 磨到 0.2 dB 而消耗迭代輪次——那多半是在收斂「實作細節」而非「音樂性」。所有 Agent 執行本規格書時，遇到指標與人耳判斷衝突，一律以 Primary Goal 優先。

> **V2.0 異動摘要（策略轉向：從「100% Clone」改為「以 Saturn 2 為技術基線、往好聽的方向收斂」）**：
> 1. 新增專案目標宣告（見上），並將全案拆為 **Phase A（Saturn Matching，機器可自動收斂）** 與 **Phase B（Voice Tuning，人耳導向、需人類參與迴圈）** 兩階段
> 2. Phase A 收斂門檻放寬（THD_error < 1.0 dB、HarmonicProfileError < 2.0 dB），不再追求前版 0.5dB/1.0dB 的精確 null match
> 3. 架構新增第四個音樂性槓桿：**Soft Compression Component**（極輕微比例的包絡跟隨壓縮，H9）
> 4. H3（對稱性）從二元判斷升級為連續可調的 **Even/Odd Blend** 參數化
> 5. 假設探索順序依「對音樂性的影響力」重排（H8 動態偏壓提前，H1 Oversampling 微調延後）
> 6. 新增 4.6 節：Phase B 人耳導向迭代協議（LISTEN 步驟、人類簽核閘門、感知回饋量表）
> 7. 新增 3.6 節：技術槓桿 ↔ 感知描述對照表，讓人類的主觀回饋能直接轉譯成下一輪假設

> **V2.1 異動摘要（修補 Phase A/B 交界處的邏輯漏洞）**：
> 1. **Phase A Exit Gate 新增 Human Override**：人類可隨時判定「已經足夠接近，可以進 Phase B」，不必等到系統判定停滯才觸發（原本這條豁免誤埋在停滯條件底下，邏輯位置錯了，見 4.5 節）
> 2. **新增 R-ReferenceFreeze**：進入 Phase B 後，Saturn 2 正式停止作為優化目標，僅保留技術參考用途；Agent 不得因為技術指標比 Phase A 差就自行嘗試拉回，任何回退必須由人類明確指示（見 4.6 節）
> 3. **H9 更名並擴大為「Dynamic Energy Control」傘狀類別**：Soft Compression 保留為預設起點與最先驗證的候選實作，若無法解釋聽感落差，可擴展至 Envelope Modulation / Micro-Sag / Level-Dependent Gain（見 3.2-B）
> 4. **新增 R-Musicality**：Phase B 中若客觀指標變差但人耳多次確認變好聽，允許保留該修改，並標記為 `musically_preferred_deviation`，與 R-ReferenceFreeze 互為表裡（見 4.6 節）
> 5. **3.6 對照表加註但書**：明確標註「經驗法則、非唯一原因，多對多關係，最終仍需實驗驗證」，並補上「太硬/刺耳」與 Oversampling 混疊的交叉診斷路徑
> 6. **新增 `reference_notes/` 分素材紀錄**：Phase B 的人耳回饋依素材類型（vocal / bass / drumbus / mixbus）拆分記錄，取代單一大檔案

> **V2.2 異動摘要（實驗方法與狀態語意的關鍵修正——只收會實際影響 Loop 判斷或評估可信度的三項，其餘見文末「開跑後 backlog」）**：
> 1. **R-Loss 改為門檻正規化（normalized）Loss**：原公式直接加權混合了不同尺度與正負號的指標（Sweep 是負 dB、量級比 THD/Harmonic 大一個數量級），導致標稱的 0.5/0.3/0.2 權重在數學上不成立、Sweep 項實質主導總分。改為每個指標先除以/相對於自己的收斂門檻轉成無因次比值再加權（見 5.1 節 R-Loss）
> 2. **Phase B 新增 R-ListeningProtocol（響度匹配強制）**：人耳評估前必須做等響度匹配，否則「變好聽」可能只是「變大聲」的感知偏誤，會讓整個 Voice Tuning 失去意義。響度匹配為強制項；完整盲測形式為建議項（做不到時標記 `listening_blinded: false`）（見 4.6 節）
> 3. **Human Override 與技術收斂的 status/tag 分流**：人類提前終止時不再標記為 `phase_a_converged`／`-saturn-like`（會讓未達門檻的版本被誤認為已技術收斂），改為 `phase_a_exited` + `phase_a_exit` 結構化欄位 + `-baseline-approved` tag（見 4.5 節）
> 4. **附帶修正 7.1**：multiband_tool 啟動條件的矛盾措辭（「進入 voice_tuning」vs「voice_signoff.final」）已釐清為兩階段（見 4.5 節末）
>
> 其餘 Copilot 審查點（假設清單拆分、動態測試訊號 05–07、Git LFS 容量政策、W-H 非唯一性聲明、Even/Odd Blend 非正交描述、commit 兩階段狀態、「多次聆聽」最小定義）均屬合理但非阻斷性，列入文末「開跑後 backlog」，待實際執行撞到對應問題時再補，避免規格過早膨脹。

---

## 0. 文件目的與使用方式

本文件是一份可直接執行的 Loop Engineering 規格書，延續前一份《Gunshot Explosion Multiband Envelope Shaper》專案的協議格式，但**任務本質不同**，請先讀完第 1 節再開始執行。對人類而言是完整的技術規格文件；對執行代理而言是一份可操作的任務協議（Task Protocol）。文件內所有標示為 **【LOOP 規則】** 的區塊屬於強制性指令，執行時必須逐條遵守，不得自行簡化或跳過。

觸發方式：「請依照 SPECIFICATION 執行 Loop Engineering，直到收斂或達到最大迭代次數」。

> **【LOOP 規則 R0】** 每一輪迭代開始前，必須先讀取 `loop_state.json` 確認目前作用中的模式軌道（track）、迭代編號、歷史指標與尚未驗證的假設清單，禁止憑記憶或猜測狀態。

> **本專案與前案的關鍵差異（務必注意）**：
> 1. 前案（Envelope Shaper）逆向工程的是「動態瞬態塑形」，目標指標是頻譜誤差＋包絡相關性；本案逆向工程的是「靜態／準靜態非線性染色曲線」（飽和/諧波生成），目標指標改為 **THD、諧波量譜誤差、頻率響應誤差**。
> 2. 前案 Cubase 面板參數是已知的固定目標值；本案 **完全沒有 Saturn 2 內部參數的存取權**，一切都必須從渲染後的音檔黑箱量測回推。
> 3. 前案只有一個交越網路規格（Cubase 給定）；本案的「分頻＋每頻段 Dry/Wet」是**使用者自行設計的工具功能**，不是要去逼近 Saturn 2 的分頻行為 — 只有「單頻段染色核心」需要對照 Saturn 2 渲染檔逆向工程，分頻與 Dry/Wet 混合層是在核心驗證通過後疊加的自有架構。
> 4. 前案已有參考音檔；本案**目前沒有任何參考渲染檔**，Iteration 0 之前多了一個「Iteration -1：測試訊號生成與待渲染清單」步驟。

---

## 1. 專案概述

以 MATLAB R2026a（Audio Toolbox + Signal Processing Toolbox）為 FabFilter Saturn 2 的兩個染色模式 — **Subtle Saturation** 與 **Subtle Tube** — 建立技術基線，並在此基線上調校出一個使用者真正想用的多頻段 Tube/Saturation 染色工具：

- 可設定的分頻網路（頻段數量與交越頻率可調，非鎖定 Saturn 2 原生分頻）
- 每個頻段獨立選擇染色模式與版本（見下方 Phase B 版本進程）
- 每個頻段獨立的 Dry/Wet 混合比例（0–100%）
- 最終加總輸出

### 兩階段策略

**Phase A — Saturn Matching（機器可自動收斂，見第 5 節）**
目標：單頻段、100% Wet、無分頻污染情況下，染色核心模型輸出與 Saturn 2 實際渲染音檔「足夠接近」（約 90% 相似度量級，非逐位元 null match）。這是建立可信度與可解釋基線的手段，門檻刻意放寬（見 5.1 節），達標即停止在此階段繼續磨指標。

**Phase B — Voice Tuning（人耳導向，需人類參與迴圈，見 4.6 節）**
在 Phase A 基線之上，往「好聽」的方向調整，脫離 Saturn 2 的束縛。每個 track 各自產生三個版本，逐步遞進：

| 版本 | 定位 |
|---|---|
| `<mode>-saturn-like` | Phase A 收斂後直接凍結的版本，忠實於 Saturn 2 測得的行為 |
| `<mode>-enhanced` | 依人耳回饋做第一輪調整（Harmonic Tilt、Dynamic Bias、Dynamic Energy Control 等槓桿） |
| `<mode>-final` | 定案版本，人類簽核確認滿意後鎖定 |

其中 `<mode>` ∈ {`subtle_saturation`, `subtle_tube`}。多頻段工具最終使用的是 Phase B 產出的 `-final` 版本，而非 `-saturn-like` 版本。

GitHub Repository：尚未建立，見第 6 節「全新專案建置流程」。

---

## 2. 執行環境與資料路徑

- MATLAB R2026a + Audio Toolbox + Signal Processing Toolbox
- Git 與 Git LFS（`*.wav` 一律經 LFS 追蹤）
- 乾聲測試訊號（無版權疑慮，本機生成）：`data/dry/`
  - `01_tone_battery.wav`　　　多頻率×多電平正弦音階，含前導校準click，附 `dry_signal_manifest.json` 標記每段取樣點位置
  - `02_log_sweep_moderate_-18dBFS.wav`　20Hz–20kHz 對數掃頻（中等電平）
  - `03_log_sweep_hot_-3dBFS.wav`　　　20Hz–20kHz 對數掃頻（近滿電平）
  - `04_pink_noise_broadband_-12dBFS.wav`　寬頻粉紅噪音（音色整體性 sanity check 用）
  - 上述四檔已由本次對話生成並交付（見對話附件），並附上等效的 `tools/generateTestSignals.m`，可在 repo 內重新產生，確保可重現性
- 參考渲染檔（**目前不存在，待使用者提供**）：`data/reference/<mode>/<同名 dry 檔案>`，其中 `<mode>` ∈ {`subtle_saturation`, `subtle_tube`}
- 真實素材（**Phase B 才需要，目前不存在，待使用者提供**）：`data/program_material/`（人聲、貝斯、鼓組 bus、2-mix 各 10–30 秒，僅用於人耳判斷，不送 Saturn 2 渲染、不作逆向工程對照，見 4.6 節）
- MATLAB 輸出檔：`output/<track>/iter_<ID>/<同名檔案>`（Phase A）、`output/<track>/voice/<voice_stage>/iter_<ID>/`（Phase B），其中 `<track>` ∈ {`subtle_saturation`, `subtle_tube`, `multiband_tool`}

> **【LOOP 規則 R1】** 路徑不得寫死於函式內部，必須集中於 `config.m` 管理；修改參數時只能改動設定檔，不得直接修改演算法主體中的常數。

> **【LOOP 規則 R1-A】參考資產閘門（Reference Asset Gate）**
> 任何一輪迭代在計算指標前，必須先確認該輪所需的 `data/reference/<mode>/` 對應檔案是否存在。若不存在：
> - 禁止用模擬、猜測、或用另一模式的渲染檔替代來「暫時跑通」流程
> - 必須將 `loop_state.json` 的 `status` 設為 `awaiting_reference_assets`，並在 `loop_iterations/iter_<ID>/hypothesis.md` 中明確列出「需要使用者渲染並提供的檔案清單」
> - 終止本輪，等待使用者提供檔案後才可繼續
>
> **防呆（強制）**：當偵測到某 track 的 `status` 已是 `awaiting_reference_assets` 且所需檔案仍未齊全時，Agent 必須**立即輸出所需檔案清單並主動中斷本次執行**，不得自動進入下一輪循環、不得重複讀取 `loop_state.json` 再次印出相同等待訊息、不得以任何形式空轉重試。必須明確等待人類在對話中回覆「檔案已到位」或提供新檔案後，才可重新開始該 track 的 Iteration 0。

---

## 3. 信號處理架構

### 3.1 整體流程（兩層架構）

```
【染色核心層 — Phase A 逆向工程對象、Phase B 調校對象，每個模式獨立驗證，預設採 Wiener-Hammerstein 結構】
  單頻段全頻寬輸入 → 前置處理（DC/高通、Oversampling 上取樣）
                   → Pre-EQ  H1(f)　　　　【W-H 結構，見 3.2-A，可退化為 identity】
                   → 非線性波形整形 f(x)（Subtle Saturation 或 Subtle Tube 曲線模型，含 Even/Odd Blend）
                   → Dynamic Energy Control　【見 3.2-B，H9，預設起點為 Soft Compression，可退化為 bypass】
                   → Post-EQ H2(f)　　　　【W-H 結構，可退化為 identity】
                   → 後置濾波（抗鋸齒、降取樣）→ 輸出增益補償 → 單頻段輸出

【多頻段工具層 — 使用者自有功能，不對照 Saturn 2】
  輸入 → N 頻段交越網路（頻段數與交越頻率可設定，預設 4 頻段）
       → 每頻段：[染色核心（模式可選 Saturation/Tube/Bypass，版本固定為各 track 的 -final）] 與 [Dry 訊號] 依 Dry/Wet 比例混合
       → 頻段加總 → 輸出
```

若迭代過程中發現更優染色核心架構（例如加入頻率相關的音色網路、非對稱偏壓項、動態偏壓、軟壓縮），可在新假設分支上實驗，但必須在 commit message 與迭代報告中明確記錄架構變更理由與前後指標對比。

### 3.2 染色核心的可調自由度（Search Space）

> **【LOOP 規則 R2】搜索空間邊界（黑箱逆向工程版）**
> 由於沒有 Saturn 2 原始碼或內部參數存取權，**沒有任何「鎖定目標值」可供直接抄用** — 所有數學形式都是自由搜索空間，唯一的「固定目標」是**參考渲染檔的量測結果**。可調自由度包含但不限於：
>
> | 自由度 | 候選範圍 |
> |---|---|
> | 波形整形函數形式 | tanh、arctan、多項式（含奇次/偶次項）、分段函數、Saturn 已知常見的 soft-knee 曲線族 |
> | **Even/Odd Blend（原「非對稱偏壓」，見 3.6）** | 連續參數化：偏壓量 bias 與非對稱量 asymmetry 各自可調，直接決定 H2/H3 諧波比例，是「暖厚」vs「咬字感」的主要槓桿，Phase B 會頻繁調整此項 |
> | Oversampling 倍率 | 2x / 4x / 8x，需與參考檔的可觀測混疊特性交叉驗證；Phase A 用合理預設值即可，精細調整留到 Phase B 最後（見 3.2-C 優先序） |
> | 抗鋸齒濾波器設計 | 濾波器類型、階數、線性相位 vs 最小相位（會影響延遲對齊） |
> | 前置/後置音色網路 | 是否存在低頻/高頻 shelf 的伴隨調色（tube 類飽和常見），見 3.2-A |
> | **Dynamic Energy Control（新增，見 3.2-B，H9）** | 傘狀類別，非單一具體實作：預設起點 Soft Compression（放置位置、ratio 建議搜索範圍 1.02:1–1.15:1、attack/release 時間常數）；若無法解釋聽感落差，擴展至 Envelope Modulation / Micro-Sag / Level-Dependent Gain |
> | Drive/Amount 到內部增益的映射曲線 | 線性 dB、對數、S 曲線 |
> | 輸出增益補償／自動增益邏輯 | 固定增益 vs 依諧波能量自動補償 |
>
> 若之後在對照渲染檔時發現某個自由度其實有可觀測的固定行為（例如奇偶諧波比例幾乎不隨電平變化），才能將其收斂為「已驗證假設」寫入 `loop_state.json` 的 `hypotheses_tested`，不得憑印象假設 Saturn 2 內部一定用某種曲線。

### 3.2-A 核心候選架構：Wiener-Hammerstein 模型（Pre-EQ → Waveshaper → Post-EQ）

> **【LOOP 規則 R2-A】W-H 結構作為早期候選，非事後才補的例外**
> Saturn 2 的染色模式（尤其 Tube）很可能不是單純的靜態波形整形，而是「前置濾波 $H_1(f)$ → 靜態非線性 $f(x)$ → 後置濾波 $H_2(f)$」的 Wiener-Hammerstein 結構。**若只假設「原訊號 → 波形整形 → 輸出」，一旦參考檔實際存在前置/後置 EQ，純波形整形函數無論怎麼調，都無法同時收斂「掃頻頻率響應」與「不同頻率下的 THD 比例」——這是結構性缺陷，不是參數沒調好。**
>
> 因此：
> 1. Iteration 0 的 baseline 除了純波形整形假設外，**必須額外跑一輪 $H_1(f)$=identity、$H_2(f)$=identity 的 W-H 骨架**（此時退化為純波形整形，作為對照組）
> 2. 若診斷子指標出現「THD 誤差已收斂但 SweepSpectralError 遲遲無法收斂」或反過來的情況，這是 W-H 結構缺失的典型徵兆，應優先提升 H1(f)/H2(f) 估測為下一輪假設，而不是繼續在純波形整形函數的形式上打轉
> 3. $H_1(f)$、$H_2(f)$ 初期以簡單參數化濾波器（shelf/peaking，1–2 段）搜索即可，不必一開始就上任意階 FIR/IIR，避免過度擬合掃頻雜訊

### 3.2-B 新增槓桿：Dynamic Energy Control（H9，傘狀類別）

> **【LOOP 規則 R2-B】不要太早把這個槓桿鎖死成「壓縮器」**
> 許多好聽的類比模擬 Saturator，其舒服的聽感來源並非諧波失真本身，而是某種伴隨的動態能量控制——但這個效果的**真實機制不一定是一個獨立的乘法增益級（壓縮器）**，也可能是動態偏壓漂移（見 H8）、電源 sag、熱效應等現象的副作用被耳朵感知成「像壓縮」。若一開始就把 H9 定死成具體的壓縮器實作去搜索參數，可能在還沒驗證清楚真實成因前就把探索空間收窄錯方向，違反 R2 節「不假設具體數學形式，一切從量測/聽感回推」的精神。
>
> 因此 H9 定義為傘狀類別 **Dynamic Energy Control**，下轄候選實作（依驗證優先序）：
> 1. **Soft Compression（預設起點，最先驗證）** — 極輕微包絡跟隨壓縮：ratio 通常在 1.02:1–1.15:1 這種幾乎量不出來的範圍，搭配約 30 ms attack、100 ms release 的包絡。這種壓縮量對 THD 幾乎沒有影響（量測不出來），但對聽感的「穩定感／凝聚感／glue」有明顯貢獻。選為預設起點是因為它最容易實作、最容易做 A/B 驗證，不是因為它一定是正確答案
> 2. **Envelope Modulation** — 若 Soft Compression 調到位後聽感落差仍解釋不了，考慮讓某個既有槓桿（例如 Even/Odd Blend 的 bias 量、或 Pre-EQ 的增益量）直接隨輸入包絡調變，而非透過獨立的增益級
> 3. **Micro-Sag** — 模擬電源/供電輕微跟隨大訊號下垂的效果，通常表現為極短暫、極輕微的增益/音色雙重下陷後緩慢恢復
> 4. **Level-Dependent Gain** — 更廣義的「輸出增益本身就是輸入包絡的函數」，可能與 H8（動態偏壓）在效果上有重疊，需要雙軌對照才能分清楚是哪一個機制在起作用，不可想當然爾歸給其中一個
>
> Phase A 收斂時，H9 整體以 bypass（Soft Compression ratio=1:1，其餘候選皆關閉）處理；Phase B 才需要認真調校，且應先窮盡候選 1，解釋不了聽感落差再往候選 2–4 移動，不要一開始就四個一起搜索。
>
> 待驗證項目（以候選 1 為例）：
> 1. 放置位置 — waveshaper 之前（影響推入非線性的訊號動態）或之後（單純動態塑形，不影響諧波生成過程）
> 2. Ratio、attack、release 三個參數的合理範圍需先用 `04_pink_noise_broadband` 或使用者提供的真實素材做初步聽感掃描，不建議用純音階測試（純穩態音看不出包絡跟隨效果）

### 3.2-C 探索優先序（依「對音樂性影響力」排序，非依技術難易度）

> Phase A 與 Phase B 的假設探索**不建議**按照 H1、H2、H3... 的編號順序機械式執行，應依下列優先序（對照第 8 節的假設編號）：
>
> | 順序 | 槓桿 | 對應假設 | 理由 |
> |---|---|---|---|
> | 1 | 基礎波形整形函數 | H2 | 決定失真的骨架，必須先定型 |
> | 2 | Even/Odd Blend（非對稱） | H3 | 決定「暖厚」vs「咬字感」，音樂性影響極大 |
> | 3 | Pre/Post EQ（W-H） | H6 | 決定「清晰立體」的關鍵，且是解決 Phase A 頻譜誤差卡住的結構性手段 |
> | 4 | 輸出增益補償 | H5 | 需要先有前三項才能正確估計 |
> | 5 | 動態偏壓 | H8（Subtle Tube） | 真空管味道的核心，但需要前面架構先穩定才好隔離觀察 |
> | 6 | Dynamic Energy Control（預設先試 Soft Compression） | H9 | 「膠水感」的主要來源，Phase B 重點調校項 |
> | 7 | Oversampling 精細調整 | H1 | 主要影響混疊/正確性而非音樂性，適合留到最後微調 |
>
> Drive/Amount 映射（H4）不算在此優先序內，屬於 Iteration -1／Iteration 0 就必須先做好的校準前提（見 4.3 節）。

### 3.3 兩條獨立逆向工程軌道（Track）

Subtle Saturation 與 Subtle Tube 是兩個獨立的非線性模型，**必須分開收斂，不可共用未經雙重驗證的假設**。

> **【LOOP 規則 R3-A】軌道隔離**
> - `loop_state.json` 內以 `tracks.subtle_saturation` 與 `tracks.subtle_tube` 分別維護各自的 `current_iteration`、`best_metrics`、`hypotheses_tested`、`hypotheses_pending`、`status`
> - 一輪迭代只能推進一個軌道
> - 若某假設（例如 Oversampling 倍率）在 A 軌道驗證有效，可作為「候選」帶入 B 軌道測試，但必須在 B 軌道重新跑一輪驗證並記錄結果，不可直接視為已驗證後套用

### 3.4 分頻網路（多頻段工具層，非逆向工程對象）

- 預設頻段數：4（可於 `config.m` 調整為 2–6 段）
- 預設交越頻率：使用者可自訂；若無特殊需求，建議初始值 250 Hz / 1000 Hz / 4000 Hz（可調整，非鎖定）
- 交越濾波器：Linkwitz-Riley 4 階（LR4，24 dB/oct），沿用前案已驗證的實作方式，因為這是「加總後幅頻平坦」的通用工程解，與 Saturn 2 內部如何分頻無關
- **驗證方法**：全頻段 Bypass（即所有頻段染色關閉、Dry/Wet 皆為 0% wet）直接加總，與原始訊號誤差應低於 −60 dB（沿用前案方法，驗證分頻網路本身無損）

### 3.5 每頻段 Dry/Wet 與模式選擇

| 參數 | 範圍 | 說明 |
|---|---|---|
| Band Mode | Bypass / Subtle Saturation / Subtle Tube | 每頻段獨立選擇 |
| Drive/Amount | 待定（依染色核心軌道收斂後決定合理範圍） | 每頻段獨立 |
| Dry/Wet | 0–100% | 每頻段獨立，等功率（equal-power）或線性 crossfade，見 R-DryWet |

> **【LOOP 規則 R-DryWet】Dry/Wet 驗證與 Saturn 2 無關**
> Dry/Wet 混合是本工具自有功能，不需要對照 Saturn 2（Saturn 2 本身是否有全域/逐頻段 Wet 旋鈕不影響本工具設計）。驗證只需滿足：
> 1. 該頻段 Wet=0% 時，輸出必須與該頻段純 Dry 濾波後訊號逐取樣點一致（誤差 < −80 dB）
> 2. 該頻段 Wet=100% 時，輸出必須與「染色核心軌道」已驗證模型的輸出一致
> 3. 混合曲線（線性 vs 等功率）需記錄於 `config.m` 註解中並在 `FINAL_REPORT.md` 說明選擇理由

### 3.6 技術槓桿 ↔ 感知描述對照表（Phase B 回饋轉譯用）

人類在 Phase B 的 LISTEN 步驟（見 4.6 節）給出的回饋通常是主觀描述性語言，不是數值。下表用來把這些描述**初步轉譯**成第 3.2 節裡明確的技術槓桿，讓 HYPOTHESIZE 步驟有具體可執行的修改方向，而不是憑感覺亂調。

> **重要但書**：本表是**經驗法則，不是因果定論**。同一句人類描述常常是多對多關係——例如「太硬」可能來自 Even/Odd Blend（奇次比例過高），可能來自 Pre-EQ 在中高頻推升過量，也可能單純是 Oversampling 混疊被誤判成「硬」。表中「最可能」只是建議的**第一個嘗試方向**，不是唯一原因，最終仍需透過實驗（改了之後真的重新聽一次）驗證，不可只憑表格對照就直接寫進 `hypothesis.md` 當結論。

| 人類描述（範例） | 最可能對應的槓桿（非唯一，見上方但書） | 建議調整方向 | 需先排除的其他可能 |
|---|---|---|---|
| 「太硬、有咬字感、刺耳」 | Even/Odd Blend（H3） | 提高偶次比例（增加 bias）、降低奇次比例 | **先看 5.2 節的高頻混疊診斷**——若 4k/8k 測試音本身就有可觀測的鋸齒痕跡，「太硬」很可能是 Oversampling 倍率不足造成的混疊，不是音色槓桿的問題，調 Even/Odd Blend 只會白繞一圈 |
| 「太暖、太糊、少了細節」 | Even/Odd Blend（H3） | 反向操作；或檢查 Post-EQ 高頻是否衰減過多 | Pre/Post EQ（H6）的高頻補償量是否設定錯誤方向 |
| 「單薄、沒有份量」 | Dynamic Bias（H8）、Pre-EQ 低頻（H6） | 檢查低電平時的偏壓量是否不足；嘗試 Pre-EQ 低頻小幅推升 | Dynamic Energy Control（H9）候選 4（Level-Dependent Gain）是否過度壓縮了低頻能量 |
| 「悶、不夠立體、不夠清晰」 | Pre/Post EQ（H6） | 這正是 pre-emphasis 的典型徵狀：+2dB@3k 進 waveshaper 產生高頻諧波，Post-EQ 再補償拉平頻響 | Oversampling 抗鋸齒濾波器是否把高頻砍太多 |
| 「鬆散、沒有凝聚感、沒有 glue」 | Dynamic Energy Control（H9，先試 Soft Compression） | 提高 ratio（在 1.02–1.15:1 範圍內小幅增加）或縮短 attack | 若調整 Soft Compression 參數對這個描述完全沒有影響，代表真實成因可能是 H9 候選 2–4（Envelope Modulation / Micro-Sag），而不是候選 1 |
| 「壓得太死、沒有動態、悶住」 | Dynamic Energy Control（H9） | 降低 ratio 或拉長 release | 同上，也可能是 H8 動態偏壓過量 |
| 「數位感、有點刺、高頻粗糙」 | Oversampling（H1） | 檢查是否有可聽見的混疊，考慮提高 Oversampling 倍率 | Even/Odd Blend 的奇次比例是否也偏高，兩者常同時出現，需分開驗證哪個貢獻較大 |
| 「聽起來對，但總覺得少了什麼說不上來」 | 綜合，優先檢查 H8 動態偏壓 | 動態偏壓的效果很微妙但耳朵敏感，THD 量測往往看不出差異，這正是「THD 看不出但耳朵聽得出」的典型情況 | — |

此表為起始對照，執行過程中若發現新的描述↔槓桿對應關係（含「排除了 A 才發現其實是 B」的反例），應持續補充進 `loop_iterations/<track>/reference_notes/`（依素材類型分檔，見 4.6 節與第 7 節目錄結構），累積成專案自己的調校詞彙表。

---

## 4. Loop Engineering 執行協議

### 4.1 核心循環（每輪必須依序執行）

1. **READ STATE** — 讀取 `loop_state.json`，確認作用中的 track
2. **CHECK ASSETS** — 依 R1-A 確認本輪所需參考檔是否存在，不存在則終止本輪
3. **HYPOTHESIZE** — 提出本輪唯一假設，寫入 `loop_iterations/<track>/iter_<ID>/hypothesis.md`
4. **BRANCH** — 建立分支 `hypothesis/<track>-<描述>-<ID>`
5. **IMPLEMENT** — 修改 `config.m` 或演算法程式碼，變更範圍限於假設所述
6. **RUN** — `matlab -batch "run_pipeline('<track>')"`
7. **MEASURE** — `analyzeAndCompare('<track>')`，寫入 `loop_iterations/<track>/iter_<ID>/metrics.json`
8. **EVALUATE** — 依第 5 節收斂標準判斷
9. **COMMIT** — 不論結果好壞一律 commit + push
10. **UPDATE STATE** — 更新 `loop_state.json` 對應 track 的欄位
11. **DECIDE** — 該 track 收斂則執行終止程序；否則回到步驟 1（可切換至另一 track 或繼續同一 track）

### 4.2 `loop_state.json` 格式

```json
{
  "tracks": {
    "subtle_saturation": {
      "phase": "saturn_matching",
      "current_iteration": 0,
      "max_iterations": 20,
      "best_metrics": null,
      "hypotheses_tested": [],
      "hypotheses_pending": ["H2", "H3", "H6", "H5", "H9", "H1"],
      "status": "awaiting_reference_assets",
      "phase_a_exit": null,
      "voice_stage": null,
      "voice_signoff": {"enhanced": false, "final": false}
    },
    "subtle_tube": {
      "phase": "saturn_matching",
      "current_iteration": 0,
      "max_iterations": 20,
      "best_metrics": null,
      "hypotheses_tested": [],
      "hypotheses_pending": ["H2", "H3", "H6", "H5", "H8", "H9", "H1", "H7"],
      "status": "awaiting_reference_assets",
      "phase_a_exit": null,
      "voice_stage": null,
      "voice_signoff": {"enhanced": false, "final": false}
    },
    "multiband_tool": {
      "status": "blocked",
      "depends_on_scaffold": ["subtle_saturation.phase=voice_tuning", "subtle_tube.phase=voice_tuning"],
      "depends_on_integration": ["subtle_saturation.voice_signoff.final", "subtle_tube.voice_signoff.final"]
    }
  }
}
```

`phase` ∈ `saturn_matching`（Phase A，見 4.4）／`voice_tuning`（Phase B，見 4.6）。`status` 的 Phase A 終值為 `phase_a_exited`（不論技術收斂或人類提前終止，差異記在 `phase_a_exit` 結構，見 4.5），其餘可能值：`awaiting_reference_assets` / `ready` / `stalled` / `aborted`。`voice_stage` 只在 `phase = voice_tuning` 時有意義，∈ `saturn_like` / `enhanced` / `final` / `null`。`multiband_tool` 的 `blocked → (骨架階段) → ready` 轉換見 4.5 節末。`hypotheses_pending` 的順序已依 3.2-C 的探索優先序排列，非原始編號順序（H9 在 Phase A 恆為 bypass、放在 pending 中僅為完整性，實作上不需為它單獨跑一輪，詳見文末 backlog 第 4 點）。

### 4.3 Iteration -1（僅執行一次，先於 Iteration 0）：測試訊號與待渲染清單

1. 生成 `data/dry/` 四個測試檔＋`dry_signal_manifest.json`（已完成，見對話附件與 `tools/generateTestSignals.m`）
2. 產生 `render_manifest_template.csv`，請使用者針對每個 dry 檔案 × 每個模式（Subtle Saturation / Subtle Tube）填寫：使用的 Drive/Amount 數值、Oversampling 設定、Tone/Bias 類旋鈕（若有）、專案取樣率/位元深度、外掛版本、實際渲染出的檔名
3. 使用者渲染規格建議（避免引入非染色核心本身的變因）：
   - 單頻段、Full Range、Solo 該頻段
   - Wet/Mix 設為 100%（若 Saturn 2 該模式有全域 Mix 旋鈕）
   - 輸出增益補償旋鈕記錄實際數值，不要求設為 0，但必須記錄以便建模時比對
   - 專案取樣率建議與 dry 檔一致（48 kHz），若使用者慣用 96 kHz 專案，告知後可重新生成 96 kHz 版本 dry 檔
4. 使用者將渲染完成的檔案放入 `data/reference/subtle_saturation/` 與 `data/reference/subtle_tube/`，檔名需與 dry 檔一致
5. 待兩個資料夾各四個檔案齊全，`loop_state.json` 對應 track 的 `status` 才可由 `awaiting_reference_assets` 改為 `ready`，正式進入 Iteration 0

**Drive 基準映射協議（新增）**：使用者在 Saturn 2 介面上設定的 Drive 數值（例如 +3 dB 或面板刻度 2.0），對應到非線性函數輸入端內部增益乘數 $k$（即 $f(k \cdot x(t))$ 中的 $k$）是黑箱、未知的，**不可手動盲猜 $k$**。規定如下：
1. 第一次渲染固定使用 Saturn 2 該模式的**預設 Drive 值**（面板打開時的預設載入值，不要另外調整），並在 `render_manifest_template.csv` 精確記錄該預設值的顯示刻度
2. $k$ 由 `01_tone_battery.wav` 跨電平（-24 dBFS 至 0 dBFS）的 THD 成長曲線形狀自動反推——即在固定波形整形函數形式的假設下，擬合哪個 $k$ 能讓模型的 THD-vs-電平曲線與參考檔曲線形狀最吻合，$k$ 本身視為一個獨立可擬合參數寫入 `metrics.json`，而不是憑印象假設「Drive 幾 dB 面板值＝內部增益幾 dB」
3. 若之後想涵蓋其他 Drive 設定值，需額外渲染該 Drive 值的完整 tone battery，屬於後續擴充項目，非本次 Iteration 0 必要項

### 4.4 Iteration 0（Phase A，每個 track 各執行一次）

1. 建立第 7 節目錄結構
2. 設定 Git LFS 並確認 remote（見第 6 節）
3. 對齊校準：用每個檔案開頭的校準 click 計算該檔案的 `alignment_offset_samples`（見 R4）
4. 以最簡單假設（例如純 tanh 飽和 + 4x oversampling，$H_1(f)=H_2(f)=$identity，Dynamic Energy Control bypass）跑一次完整 pipeline，記錄 baseline 指標（依 R2-A，此即 W-H 骨架的退化對照組，之後若診斷指標顯示需要，直接在既有 W-H 骨架上把 $H_1$/$H_2$ 從 identity 換成實際濾波器即可，不需要重構整個 pipeline）
5. 建立該 track 初始待驗證假設清單，依 3.2-C 優先序排列（見第 8 節）
6. commit 為 `[<track>-Iter-00] baseline` 並 push

### 4.5 終止條件與終止程序（Phase A，每個 track 各自判斷）

| 條件 | 判斷標準 | 終止程序 |
|---|---|---|
| Phase A 技術收斂 | 見第 5.1 節（依 track 分別列出，門檻已放寬，見 V2.0 異動摘要） | 合併回 `main`、`git tag <track>-v<版本>-saturn-like-converged`、產生 `PHASE_A_REPORT_<track>.md`、該 track `phase` 改為 `voice_tuning`、`voice_stage` 設為 `saturn_like`、`status` = `phase_a_exited`、填寫 `phase_a_exit` 結構（見下方） |
| **人類提前終止（Human Override，獨立於下方條件）** | 人類在對話中明確表示「已經夠接近了，可以進 Phase B」——**不需要**技術指標已達 5.1 節門檻，也**不需要**先觸發下方的「停滯」條件 | 合併回 `main`、`git tag <track>-v<版本>-saturn-baseline-approved`（**與技術收斂不同 tag**）、產生 `PHASE_A_REPORT_<track>.md` 註明實際未達門檻的數值、`phase` 改為 `voice_tuning`、`voice_stage` 設為 `saturn_like`、`status` = `phase_a_exited`、填寫 `phase_a_exit` 結構 |
| 達到上限 | `current_iteration ≥ 20` | 停止，產生報告列出最佳結果與未窮盡假設，status = `stalled` |
| 停滯 | 連續 5 輪最佳指標改善 < 0.5 dB（THD/諧波誤差，門檻依 Phase A 放寬幅度同步放寬）或 < 0.5 dB（頻譜誤差） | 提前停止，產生停滯分析，status = `stalled` |
| 異常 | MATLAB 執行錯誤連續 3 次無法自行修復 | 停止，錯誤日誌保留於 `logs/`，status = `aborted` |
| 資產不足 | 見 R1-A | status = `awaiting_reference_assets`，不計入停滯輪數 |

> **【LOOP 規則 R-HumanOverride】** 人類提前終止 Phase A 這個選項**隨時有效**，不是只有在系統判定「停滯」後才能用（V2.0 版本曾把這個豁免誤埋在停滯條件底下，等於變相要求先卡 5 輪才能喊停，邏輯位置錯了，V2.1 修正為獨立條件）。Agent 不得以「還沒正式收斂／還沒判定停滯」為由拒絕或拖延人類提出的提前終止指示。

> **`phase_a_exit` 結構（V2.2 新增，區分技術收斂與人類提前終止）**：兩種離開 Phase A 的方式都把 `status` 設為 `phase_a_exited`（不再用 `phase_a_converged`，因為那個字面會讓未達門檻的 Human Override 版本被誤認為通過技術收斂），差異記錄在結構化欄位裡：
> ```json
> // 技術收斂：
> "phase_a_exit": {"reason": "technical_convergence", "technical_thresholds_met": true,  "approved_by": "automatic", "iteration": 12}
> // 人類提前終止：
> "phase_a_exit": {"reason": "human_override",         "technical_thresholds_met": false, "approved_by": "human", "iteration": 8, "note": "主觀已足夠接近，作為產品基線可接受"}
> ```
> tag 也分流：技術收斂用 `-saturn-like-converged`，Human Override 用 `-saturn-baseline-approved`。至少不讓未達門檻的版本在 metadata 或 tag 上被誤認為已技術收斂。

**multiband_tool 啟動條件（V2.2 釐清 7.1 矛盾）**：先前 4.5 與 `depends_on` 兩處措辭不一致（一個寫「進入 voice_tuning 即可」、一個寫「voice_signoff.final 才行」），實際是兩個不同階段，明確拆分如下：
- 當兩個 track 皆進入 `voice_tuning`（不論技術收斂或人類提前終止）後：允許建立 `multiband_tool` 的**程式骨架與自動化測試**（分頻網路、Dry/Wet 混合器的邊界驗證等，見 3.4/3.5），但**不得**執行最終音色整合與簽核。
- 只有當兩個 track 的 `voice_signoff.final` 皆為 `true` 後：`multiband_tool` 才可由 `blocked` 改為 `ready`，正式進入整合驗證，且此時使用的是 Phase B 的 `-final` 版本，不是 Phase A 剛結束的 `-saturn-like` 版本。

> **【LOOP 規則 R3】單一變因**
> 每輪只能驗證一個假設。禁止在同一輪同時改動波形整形函數形式與 Oversampling 倍率；若指標惡化，下一輪必須先回到上一個最佳 commit 再嘗試新假設，不得在惡化的基礎上繼續疊加修改。（此規則在 Phase A 為強制；Phase B 見 4.6 節的 R3-Voice，稍有放寬。）

### 4.6 Phase B：Voice Tuning 執行協議（人耳導向迭代循環）

> Phase A 是機器對照參考檔自動收斂；Phase B **不是**——因為好不好聽只有人耳能判斷，MATLAB pipeline 沒有耳朵。Phase B 必須是人類參與迴圈（human-in-the-loop）的協議，不能延用 Phase A 那種全自動 EVALUATE。

**新增素材需求**：Phase B 不能只用 `01_tone_battery.wav` 這類純音階測試，因為「glue」「份量」「凝聚感」這些特質在穩態純音上幾乎聽不出來。使用者需額外提供 `data/program_material/` 內幾段自己在意的真實素材（建議至少涵蓋：一段人聲、一段貝斯、一段鼓組 bus、一段完整 2-mix，各 10–30 秒即可，不需要整首歌）。這些素材**不需要**也不應該送進 Saturn 2 渲染參考——它們只用來讓人類在 Phase B 判斷「好不好聽」，不作為逆向工程對照。

**Phase B 核心循環（取代 4.1 節的自動循環）**：

1. **READ STATE** — 確認 track 的 `phase = voice_tuning`、目前 `voice_stage`
2. **RENDER CANDIDATE** — 用目前最佳配置跑過 `data/program_material/` 的素材，輸出到 `output/<track>/voice/<voice_stage>/iter_<ID>/`，並依 R-ListeningProtocol 產生**響度匹配的聆聽集**（Dry / 前一輪保留版 / 本輪候選 / Phase A saturn-like 參考），同時仍計算 Phase A 的技術指標（THD/Harmonic/Sweep）供記錄，但**這些指標此階段僅供參考，不作為收斂依據**（見下方 R-ReferenceFreeze）
3. **LISTEN** — 人類實際聆聽**響度匹配後**的渲染結果（見 R-ListeningProtocol），用第 3.6 節的感知描述詞彙給出回饋，依素材類型分別寫入 `loop_iterations/<track>/reference_notes/{vocal,bass,drumbus,mixbus}.md`（格式：版本／描述／喜歡或不喜歡／相對上一版的比較），不要全部塞進同一個檔案——半年後回頭找「Version 12 為什麼比較好聽」時，分檔案會比一個大檔案好查得多
4. **TRANSLATE** — 依 3.6 節對照表，把人類的描述性回饋轉譯成具體技術假設（例如「太硬」→ 先排除混疊可能，再考慮提高 Even/Odd Blend 的 bias）
5. **HYPOTHESIZE** — 寫入 `loop_iterations/<track>/voice/<voice_stage>/iter_<ID>/hypothesis.md`，說明本輪要調整哪個槓桿、依據哪條人類回饋
6. **IMPLEMENT / RUN** — 同 Phase A
7. **COMMIT** — commit message 格式：`[<track>-Voice-<stage>-Iter-<ID>] <變更摘要> | 人類回饋: <一句話摘要> | <improved/regressed/kept/musically_preferred_deviation>`（`improved/regressed` 由人類在下一輪 LISTEN 時判斷，不是機器判斷）
8. **DECIDE** — **不設數值門檻**，由人類明確表示「這個版本我滿意，可以定案」時，才將 `voice_stage` 推進（`saturn_like → enhanced → enhanced → final`，可在 enhanced 停留多輪），並在 `loop_state.json` 的 `voice_signoff` 標記為 `true`

> **【LOOP 規則 R-ListeningProtocol】Phase B 聆聽條件控制（V2.2 新增，強制）**
> Phase B 的 improved / regressed / musically_preferred_deviation 判斷**不得**只依未匹配音量的直接比較得出。原因是聲學心理學上「較大聲的版本」很容易被感知成「比較厚、比較清楚、比較有 punch、比較好聽」——Saturator 只要輸出多 0.3–0.8 dB 就足以造成這種偏誤。若不控制，整個 Voice Tuning 可能實際上是在挑「比較大聲」而非「比較好聽」的版本，Primary Goal 形同虛設。
>
> **響度匹配（強制，不可省略）**：
> 1. 每輪聆聽集至少輸出四個版本：(a) Dry、(b) 前一輪保留版、(c) 本輪候選版、(d) Phase A `saturn-like` 版（僅作聲音座標參考）
> 2. 正式簽核（尤其 `enhanced → final`）前，前一輪版與本輪候選版**必須**做 loudness-matched 比較
> 3. 音量補償值**只用於監聽比較**，不得寫回演算法參數（否則等於偷偷加了一個輸出增益變因）
> 4. **禁止**用 peak normalization 作為主要音量匹配方法；應優先用整段或有效區段的 perceived loudness（例如 LUFS）或 RMS-energy matching。實際監聽補償量記錄於 `output/<track>/voice/<voice_stage>/iter_<ID>/listening_manifest.json`
>
> **盲測（建議，非強制）**：候選檔應盡量以 A/B 或 A/B/X 匿名方式呈現，檔名不得直接暴露哪個是新版。但這是單人專案、盲測對單一聽者的效力本就有限，若執行環境或流程難以完成正式盲測，允許放行，但必須在對應 `reference_notes/<素材>.md` 標記 `listening_blinded: false`，以便日後判讀該次結論的可信度。
>
> 新增輔助工具：`tools/renderListeningSet.m`（產生四版本聆聽集並做響度匹配）、`tools/createBlindListeningManifest.m`（產生匿名對照清單與 `listening_manifest.json`）。

> **【LOOP 規則 R-ReferenceFreeze】進入 Phase B 後，Saturn 2 不再是優化目標（V2.1 新增，重要）**
> 一旦 track 的 `phase` 變成 `voice_tuning`，Saturn 2 的渲染檔**正式停止作為優化目標**，只保留技術參考用途（供 `PHASE_B_REPORT` 記錄「這一版跟 Saturn 2 差了多少」這種資訊性數字）。這條規則要解決的具體風險是：Phase A 收斂時 THD 可能是 0.8 dB，Phase B 為了做出個性刻意調整 Even/Odd Blend 之後，THD 變成 1.6 dB——**這是預期中、甚至是期望中的結果，不是 regression**。
> - Agent **不得**因為看到「技術指標比 Phase A 差」就自行嘗試把參數拉回去貼近 Saturn 2
> - 任何想要「往 Saturn 2 方向修正」的調整，必須由人類在對話中明確指示（例如人類自己說「這個方向太過頭了，拉回去一點」），Agent 不可主動提議或執行
> - `analyzeAndCompare` 在 Phase B 仍然照跑、照記錄數字，只是這些數字的角色從「收斂依據」徹底改成「歷史紀錄」，EVALUATE 步驟不得用它們判斷 improved/regressed

> **【LOOP 規則 R-Musicality】測起來更差、但聽起來更好，允許保留**
> 若 Phase B 某次調整讓客觀技術指標變差，但人類在多次聆聽後確認「這樣比較好聽」，允許保留該修改，並在 commit message 與 `metrics.json` 中明確標記 `musically_preferred_deviation: true`，同時在對應的 `reference_notes/<素材>.md` 記錄下人類當時的判斷理由。這條規則與 R-ReferenceFreeze 是一體兩面：R-ReferenceFreeze 防止系統自己想把它拉回去，R-Musicality 則是把人類這個刻意選擇的決策留下明確紀錄，避免半年後看到「這輪指標變差了」誤以為是哪裡壞掉需要修。很多經典類比器材本來就是「量測不是最好，但聽感最好」，這是正常現象，不是異常。

> **【LOOP 規則 R3-Voice】Phase B 的單一變因原則（放寬版）**
> 仍建議一輪只調整一個槓桿以利追蹤因果，但若人類同時給出兩個明確相關的回饋（例如「太硬」＋「太薄」同時指向 Even/Odd Blend 與 Dynamic Bias 兩個獨立槓桿），允許同輪一起調整，前提是 commit message 與 hypothesis.md 必須清楚列出兩項調整分別對應哪條回饋，以維持可追溯性。

> **【LOOP 規則 R-VoiceGate】人類簽核閘門**
> `voice_stage` 從 `enhanced` 推進到 `final` **必須**由人類在對話中明確表示滿意（例如「這版可以定案」「鎖定這版當 final」），Agent 不得自行判定「已經調得夠好」就自動推進到 final，也不得因為迭代輪數過多就自動放棄調校並強行定案——輪次過多時應如實回報目前卡住的描述性問題，讓人類決定要繼續調或先定案。

---

## 5. 驗證指標與收斂標準

### 5.1 染色核心主指標（Phase A 專用，每個 track 分別計算，取代前案的 SpectralError/EnvCorr 組合）

> **門檻已依 V2.0 策略調整放寬**：這些數值是「足夠接近 Saturn 2、建立可信基線」的門檻，不是最終產品品質的目標。達標後即進入 Phase B，**不應**為了把數字磨得更漂亮而繼續消耗 Phase A 的迭代輪次（見開頭的 Primary/Secondary Goal 宣告）。

| 指標 | 目標 | 定義 |
|---|---|---|
| THD_error | < 1.0 dB（跨所有測試頻率×電平的平均絕對誤差） | 由 `01_tone_battery.wav` 各分段量測輸出 THD（相對基頻能量比），與參考檔對應分段比較 |
| HarmonicProfileError | < 2.0 dB RMS | 各測試點 H2–H6 諧波量測誤差的 RMS（同時觀察奇偶諧波比例，判斷是否為 Tube 特有的非對稱行為） |
| SweepSpectralError | < −20 dB | 對 `02`/`03` 掃頻檔用反向濾波器（Farina 解卷積）分離出諧波階數後的頻譜誤差 |
| BroadbandTonalError | < −18 dB | `04_pink_noise` 檔的 STFT 頻譜誤差（4096-point、75% overlap、Hann 窗，能量歸一化），僅作整體音色 sanity check，非主要收斂依據 |
| AlignmentOffsetStability | 同一模式跨檔案的 offset 差異 < 2 samples | 此項不放寬——這是正確性檢查，不是相似度檢查，若差異過大代表 Oversampling/濾波器延遲模型有誤 |

> **【LOOP 規則 R-Loss】多指標衝突時的判斷準則（improved / regressed 的裁定依據）— V2.2 改為門檻正規化**
> 迭代中後期常出現「THD_error 改善但 HarmonicProfileError 惡化」這類 Pareto 衝突，單看單一指標無法判斷 EVALUATE 步驟該標記 `improved` 還是 `regressed`。
>
> **為什麼不能直接加權原始值**：三個指標的尺度與正負號都不同——THD_error / HarmonicProfileError 是越小越好的正值（量級約 0–2），SweepSpectralError 是越負越好的 dB 值（量級約 −10 到 −30）。若直接對原始值加權，Sweep 項因為量級大一個數量級，不管權重標多小都會實質主導總分，標稱的 0.5/0.3/0.2 優先序在數學上根本不成立。因此**所有指標必須先轉成無因次的 normalized error（相對於各自的收斂門檻）再加權**：
>
> $$\text{THD\_norm} = \frac{\text{THD\_error}}{\text{THD\_target}}, \quad \text{Harmonic\_norm} = \frac{\text{HarmonicProfileError}}{\text{HarmonicProfileError\_target}}$$
> $$\text{Sweep\_norm} = 10^{(\text{SweepSpectralError} - \text{SweepSpectralError\_target})/20}$$
>
> Sweep 因為越負越好、且是 dB 量，用上式轉換：實測值等於目標（−20 dB）時 Sweep_norm = 1，優於目標時 < 1，劣於目標時 > 1，方向與量級都與另兩項一致。三項的門檻取自本節表格（THD_target = 1.0、Harmonic_target = 2.0、Sweep_target = −20）。
>
> $$\text{NormalizedLoss} = w_1 \cdot \text{Harmonic\_norm} + w_2 \cdot \text{THD\_norm} + w_3 \cdot \text{Sweep\_norm}$$
>
> 正規化後每個指標「剛好達標」時都等於 1，權重才真正具備可比較意義。起始權重 $w_1 = 0.5$（諧波奇偶結構，最決定失真音色）> $w_2 = 0.3$（整體失真量）> $w_3 = 0.2$（掃頻誤差，需先確認 R2-A 的 W-H 結構已納入，否則此項易長期卡住）。
>
> **判定規則**：`NormalizedLoss` 相對上一個最佳值下降 ≥ 0.05（正規化後的無因次量）且無單一 normalized 子指標惡化超過 0.5，視為 `improved`；否則 `regressed`。
>
> **權重版本化（強制）**：權重一旦調整，前後 iteration 的 Loss 就不在同一尺度、不能直接比較。因此每次調整必須在 `metrics.json` 記錄：
> ```json
> {"loss_version": "phase_a_loss_v1", "weights": {"harmonic": 0.5, "thd": 0.3, "sweep": 0.2}, "changed_at_iteration": 7, "reason": "..."}
> ```
> 比較兩輪 Loss 前必須先確認 `loss_version` 相同；跨版本的 Loss 數值不可直接比大小。
>
> 這組權重是**起始值，不是鐵律**——若實際過程中發現某指標對聽感／後續影響明顯更大，應在 `hypothesis.md` 記錄理由後調整。`NormalizedLoss` 只作為 improved/regressed 的裁定依據，commit message 仍需完整列出三項**原始**指標數值（見 6.3 節），不可只寫 Loss 總分。

### 5.2 診斷用子指標（每輪必須計算）

- 各測試電平下的 THD 曲線形狀（是否有膝點、飽和區）
- 奇次 vs 偶次諧波能量比（Tube 通常偶次諧波比例較高、較不對稱）
- 高頻段（4k/8k 測試音）是否有可觀測的鋸齒/混疊痕跡（Oversampling 倍率不足的訊號）
- Drive/電平 → 輸出增益補償量的映射曲線誤差

> **【LOOP 規則 R4】對齊優先（含亞取樣點對齊）**
> 必須先用每個檔案開頭的校準 click 做 cross-correlation 抓出 `alignment_offset_samples`，補償對齊後才能計算任何指標。未對齊的指標一律視為無效。
>
> **亞取樣點對齊（新增，強制）**：非線性整形本身不存在單一「群延遲」，但訊號鏈中的 LTI 級聯部分——Oversampling 上/降取樣濾波器、R2-A 的 Pre-EQ $H_1(f)$／Post-EQ $H_2(f)$——確實會引入非整數取樣點的群延遲。若只用整數取樣點的 cross-correlation 對齊，殘餘的次取樣點誤差會讓高頻諧波與相位敏感指標（尤其 SweepSpectralError）出現與實際模型優劣無關的巨大虛假誤差。因此：
> 1. 對齊必須支援亞取樣點精度（sinc 內插重取樣後再 cross-correlation，或以互相關相位斜率法／phase correlation 估測分數延遲）
> 2. 先用校準 click 導出整數＋分數兩部分的延遲補償值，都記錄在 `metrics.json` 的 `alignment_offset_samples`（整數部分）與新增欄位 `alignment_offset_fractional`（分數部分，單位為 sample 的小數）
> 3. 對齊後的分數延遲量級應與該模式當下假設的濾波器理論群延遲相符；若明顯不符，代表濾波器設計假設（類型/階數/線性相位 vs 最小相位）可能錯誤，本身即是一項診斷線索，應寫入 hypothesis 分析，而不是略過不管

### 5.3 多頻段工具層驗證（不對照 Saturn 2，見 R-DryWet）

- 全 Bypass 加總誤差 < −60 dB
- 各頻段 Wet=0%／100% 邊界情況驗證（見 3.5 節）
- 跨頻段切換時無明顯 click/不連續（相鄰頻段增益切換平滑度，人耳＋數值雙重檢查）

---

## 6. Git 工作流程（全新專案，尚未建立 Repository）

### 6.1 GitHub 專案建立步驟（使用者需在自己機器上執行一次）

**方式 A：用 GitHub 網頁介面**
1. 登入 GitHub → New repository
2. Repository name 建議：`saturn2-subtle-colorizer`（或自訂）
3. Visibility：依需求選 Private 或 Public
4. **不要**勾選自動建立 README / .gitignore / License（本地端會自行建立，避免衝突）
5. 建立後複製 remote URL（HTTPS，例如 `https://github.com/<你的帳號>/saturn2-subtle-colorizer.git`）

**方式 B：用 GitHub CLI（若已安裝 `gh` 並登入）**
```bash
gh repo create saturn2-subtle-colorizer --private --source=. --remote=origin
```

**本地端初始化（不論方式 A 或 B 都需要）**
```bash
cd <專案資料夾>
git init
git lfs install
git lfs track "*.wav"
git add .gitattributes .gitignore
git add .
git commit -m "[Iter-(-1)] project scaffold + dry test signals"
git branch -M main
git remote add origin https://github.com/<你的帳號>/saturn2-subtle-colorizer.git
git push -u origin main
```

> 若採用方式 A，第一次 `git remote add origin ...` 的 URL 就是步驟 5 複製的網址；若採用方式 B，`gh repo create` 已自動設定好 remote，可跳過該行。

### 6.2 分支策略

| 分支 | 用途 | 規則 |
|---|---|---|
| `main` | 僅存放 baseline 與各 track 已收斂結果 | 只能由收斂分支合併進入 |
| `hypothesis/<track>-<描述>-<ID>` | 每輪假設實驗 | 一輪一分支；不論成敗都 push 保留 |

### 6.3 Commit Message 格式（強制）

```
[<track>-Iter-<ID>] <變更摘要> | THD_error=<值>dB | HarmonicProfileError=<值>dB | SweepSpectralError=<值>dB | <improved/regressed/converged>
```

`<track>` ∈ `subsat` / `subtube` / `multiband`

### 6.4 認證

HTTPS + Personal Access Token，token 以環境變數 `GITHUB_TOKEN` 提供或使用 git credential helper。

> **【LOOP 規則 R5】憑證安全**
> Token 絕對不可出現於任何會被 commit 的檔案、commit message、日誌或報告中。每次 commit 前必須確認 staged 檔案不含 `.env` 與任何憑證字串。

### 6.5 Git 環境備援機制（新增）

在無互動式 Shell（例如某些 CI/CD 或 Agent 執行環境）中，`git commit` 可能因下列原因失敗而導致 Loop 中斷：
- 未設定 `user.name` / `user.email`
- `GITHUB_TOKEN` 缺失或過期，導致 `git push` 失敗

> **【LOOP 規則 R-GitFallback】**
> 1. 每輪 COMMIT 步驟前，先檢查 `git config user.name` / `user.email` 是否已設定；若未設定，使用專案層級設定（`git config user.email "loop-engineering@local"`、`git config user.name "Loop Engineering Agent"`），並在 `logs/git.log` 記錄一筆警告
> 2. 若 `git push` 失敗（憑證缺失、網路不通等），**允許備援模式**：僅完成本地 `git commit`，跳過 `push`，將失敗原因與待推送的 commit hash 寫入 `logs/git.log`，並在 `loop_state.json` 對應 track 新增 `pending_push: true` 標記
> 3. 備援模式不視為 R1-A 的資產不足或第 4.5 節的「異常」終止條件，Loop 可以繼續往下一輪推進；但下次 push 成功後，必須依序把所有 `pending_push` 的 commit 推送上去，不可跳過或 squash 掉中間紀錄
> 4. 備援模式啟用時，`FINAL_REPORT_<track>.md` 中必須註明「本地 commit 完整、遠端同步狀態」，避免使用者誤以為 GitHub 上的 repo 就是最終版本

---

## 7. 目錄結構

```
SPECIFICATION.md / CLAUDE.md         本規格書（任務協議入口）
loop_state.json                      循環狀態檔（含 tracks 巢狀結構）
config.m                             所有路徑、參數、可調自由度集中管理
tools/generateTestSignals.m          重新產生 data/dry/ 測試訊號（可重現性用）
tools/renderListeningSet.m            Phase B 響度匹配聆聽集產生（見 R-ListeningProtocol）
tools/createBlindListeningManifest.m  Phase B 匿名對照清單與 listening_manifest.json
render_manifest_template.csv         使用者填寫的 Saturn 2 實際渲染設定紀錄
src/                                 run_pipeline.m, crossoverBank.m,
                                      saturationCore_subtleSaturation.m,
                                      saturationCore_subtleTube.m,
                                      preEQ.m, postEQ.m（W-H 結構，見 3.2-A，可退化為 identity）,
                                      dynamicEnergyControl.m（見 3.2-B，H9 傘狀類別，內含 softCompression 子模組，可退化為 bypass）,
                                      dryWetMixer.m, bandSummary.m,
                                      analyzeAndCompare.m, harmonicSeparation.m,
                                      subsampleAlign.m（見 R4，sinc 內插/phase correlation）
data/dry/                            乾聲測試訊號（本次已交付，Git LFS）
data/reference/subtle_saturation/    使用者渲染後提供（Git LFS）
data/reference/subtle_tube/          使用者渲染後提供（Git LFS）
data/program_material/                Phase B 用真實素材（使用者提供，Git LFS，不對照 Saturn 2）
output/<track>/iter_<ID>/            Phase A 每輪輸出音檔
output/<track>/voice/<voice_stage>/iter_<ID>/   Phase B 每輪輸出音檔（含 listening_manifest.json）
loop_iterations/<track>/iter_<ID>/   hypothesis.md, metrics.json, config 快照, 分析圖表（Phase A）
loop_iterations/<track>/reference_notes/{vocal,bass,drumbus,mixbus}.md   Phase B 人類回饋，依素材類型分檔紀錄（V2.1 取代單一 voice_feedback_log.md）
logs/                                 MATLAB 執行日誌與錯誤紀錄
.gitignore / .gitattributes          忽略規則（含 .env）與 LFS 追蹤規則
```

---

## 8. 假設優先順序（初始待驗證清單）

> 編號僅為識別用，**實際探索順序請依第 3.2-C 節的優先序表**（H2 → H3 → H6 → H5 → H8 → H9 → H1），而非依編號 1、2、3... 機械式執行。此順序是依「對音樂性影響力」排的，不是依技術難易度。

### Subtle Saturation track（Phase A）
- **H2**：基礎波形整形函數形式 — tanh vs 多項式 vs soft-knee，對照 THD 曲線形狀
- **H3**：Even/Odd Blend（原「對稱性」，見 3.2 表與 3.6 節）— 連續參數化的偶次/奇次諧波比例，決定「暖厚」vs「咬字感」，Phase A 先定出合理初始值，Phase B 會頻繁回頭調整
- **H6**：W-H 結構的 Pre-EQ $H_1(f)$／Post-EQ $H_2(f)$ 是否存在（見 3.2-A）— 若 THD 已收斂但 SweepSpectralError 卡住，優先驗證此假設，而非繼續調整波形整形函數形式
- **H5**：輸出增益補償邏輯 — 固定增益 or 依諧波能量自動補償
- **H9**：Dynamic Energy Control（見 3.2-B）— 傘狀類別，Phase A 先以 bypass 處理，Phase B 才認真調校，預設先試 Soft Compression 候選
- **H1**：Oversampling 倍率 — 從高頻測試音（4k/8k）的混疊痕跡反推，Phase A 用合理預設（如 4x）即可，精細調整留到最後
- **H4**：Drive/Amount 映射曲線 — 依 4.3 節「Drive 基準映射協議」從多電平測試點反推內部增益 $k$（校準前提，不算在探索優先序內）

### Subtle Tube track（Phase A）
- **H2**：基礎波形整形函數形式
- **H3**：Even/Odd Blend — tube 類飽和通常偶次比例明顯偏高，重點檢查此項
- **H6**：W-H 結構的 Pre-EQ／Post-EQ 是否存在（tube 常見的中頻推升/高頻軟化，見 3.2-A）
- **H5**：輸出增益補償邏輯
- **H8**：動態偏壓／包絡跟隨偏壓（Envelope-dependent Bias Shift）— 真實/模擬真空管常見電容充放電導致偏壓隨輸入包絡變化，靜態非線性曲線（固定偏壓＋多項式）在高電平長音階測試段可能出現殘餘誤差。**排序已提前**（V2.0 調整）：這是真空管味道的核心特徵之一，只是需要前面幾項架構先穩定下來才好單獨觀察其效果，不是要等到「卡住才啟用」
- **H9**：Dynamic Energy Control（Phase A 先 bypass，Phase B 預設先試 Soft Compression 候選）
- **H1**：Oversampling 倍率（Phase A 用合理預設，精細調整留到最後）
- **H7**：與 Subtle Saturation 的差異點是否僅在偏壓與音色網路，或波形整形函數本身也不同（需雙軌對照後才能下結論，不可假設）
- **H4**：Drive/Amount 映射曲線 — 同上，依 Drive 基準映射協議反推 $k$（校準前提）

實際執行時應依每輪診斷子指標動態調整順序與新增假設。Phase B 的假設不再是這份靜態清單——而是由 4.6 節的 LISTEN／TRANSLATE 步驟依人類當下的具體回饋動態產生，第 3.6 節的對照表是轉譯的起點。

### Multiband tool track（待兩 track 的 Phase B `-final` 皆簽核後才開始）
- H-MB1：分頻交越頻率預設值是否需要依實際使用情境調整
- H-MB2：Dry/Wet 混合曲線（線性 vs 等功率）的實際聽感/相位行為
- H-MB3：跨頻段模式切換（例如低頻用 Tube、高頻用 Saturation）時的加總相位一致性

---

## 9. 最終交付

**Phase A 完成時**：每個 track 產生 `PHASE_A_REPORT_<track>.md`：baseline 對比、所有已驗證假設的結論摘要（含波形整形函數最終數學形式、W-H 結構參數）、殘餘誤差的頻率/電平分佈分析，並標註「此為技術基線，非最終產品音色」。

**Phase B 完成時**（人類簽核 `final` 後）：每個 track 額外產生 `PHASE_B_REPORT_<track>.md`：`saturn-like → enhanced → final` 三版本間的技術指標變化（THD/Harmonic 等，僅供記錄，依 R-ReferenceFreeze 不作為評判依據）、`reference_notes/` 各素材檔案的回饋摘要與對應調整、所有標記為 `musically_preferred_deviation` 的修改與其理由、最終各槓桿（Even/Odd Blend、Dynamic Bias、Pre/Post EQ、Dynamic Energy Control、Oversampling）的定案數值。

`multiband_tool` track 完成後，額外產生 `FINAL_REPORT_multiband.md`，說明分頻設計、Dry/Wet 混合曲線選擇理由，以及與兩個染色核心 `-final` 版本的整合驗證結果。

所有版本（`-saturn-like`、`-enhanced` 定案節點、`-final`）以 git tag 標記並推送。

> **【LOOP 規則 R6】可重現性**
> 每個 track 的 Phase A 收斂、以及 Phase B 每個簽核節點（`enhanced`/`final`）後，都必須在乾淨環境（重新 checkout tag）再執行一次 pipeline，確認指標/輸出音檔可重現後才能視為正式定案。

---

## 10. 開跑後 Backlog（合理但非阻斷性，撞到對應問題時再補，避免規格過早膨脹）

以下項目來自外部審查，判斷為正確且有價值，但**不是**從零開跑前的必要條件——它們要嘛依賴尚未存在的資料（例如 Saturn 2 參考檔還沒渲染）、要嘛只在專案跑到特定階段才會真正用到。刻意不寫進主協議，以免 Agent 被一堆還沒撞到的規則綁住或產生新的規則衝突。開跑後遇到對應觸發條件，再回頭把該項升級進主文。

1. **拆分 Phase A hypotheses 與 Phase B levers 兩份清單**
   觸發時機：實際進入 Phase B 時。目前 H9 掛在 Phase A 的 `hypotheses_pending` 裡但規定 Phase A 恆為 bypass，語意上有小歧義（已在 4.2 註明「不需為它單獨跑一輪」暫時緩解）。屆時建議把 `loop_state.json` 改為 `phase_a_hypotheses` 與 `phase_b_levers` 兩個獨立結構。注意：H8（動態偏壓）**保留在 Subtle Tube 的 Phase A**，因為若 Saturn 2 Tube 真有包絡跟隨偏壓，這是黑箱比對的技術必要假設，不只是產品音色槓桿；只有 H9 整個移到 phase_b_levers。

2. **受控動態 / IMD 測試訊號 05–07**
   觸發時機：Phase A 出現「靜態模型怎麼調都差一截」、或 H8/H9 需要證據時。新增 `05_am_tone.wav`（1kHz 載波 × 2/5/10 Hz 調變，測動態偏壓、gain pumping、recovery）、`06_tone_burst.wav`（1kHz 與 100Hz 突發音，測 attack/release、sag/bias recovery、狀態記憶）、`07_multitone_imd.wav`（互不成簡單整數倍的多音集合，測 IMD 與稠密內容非線性）。配套診斷指標：EnvelopeTrackingError、RecoveryTimeError、DynamicHarmonicError、IMDProfileError。**不設為 Phase A 硬性收斂門檻**，僅作 H8/H9 的受控診斷工具。在還沒渲染出 Saturn 2 參考檔、還不確定 Tube 到底有沒有明顯動態行為前，不需要預先做這三個訊號。

3. **Git LFS 容量政策 + 素材授權**
   觸發時機：scaffold 完成、開始產生每輪輸出前（其實可以很早做）。三分類：`data/dry/`、`data/reference/` 必進版控；`data/program_material/` 由使用者依授權與容量自行決定是否上傳；`output/` 預設 `.gitignore`，每個正式 tag 只把被簽核的代表性 audio preview + metrics + config snapshot + plots + listening_manifest 複製到白名單 `artifacts/approved_audio/` 再由 LFS 追蹤。每輪完整 WAV 視為可重建 artifact、不進 Git，正式 tag 僅保留代表性輸出與其 SHA-256。**額外提醒（非單純容量問題）**：若 `program_material/` 放的是真實商業案子素材，即使 repo 為 private，上傳任何第三方託管都有授權風險，需使用者自行確認素材授權狀態後才上傳。

4. **W-H 等效模型非唯一性聲明 + normalization convention**
   觸發時機：Phase A 開始擬合 Pre/Post EQ（H6）時。Wiener-Hammerstein 黑箱識別有經典的不可辨識性——多組 $H_1$／$f(x)$／$H_2$ 可產生近乎相同的輸出，增益會在三者間互相吸收。因此：(a) Phase A 目標應誠實表述為「取得可重現的**等效**模型」，不宣稱辨識出 Saturn 2 真實內部拓撲；(b) 多組近似解優先選參數較少、跨測試訊號泛化較好、數值穩定、更適合即時實作者；(c) 固定 normalization convention（例如 $H_1$ 在 1 kHz 增益固定 0 dB、總輸出尺度由 output gain 負責），否則 H1 gain / waveshaper drive $k$ / output compensation 三者不可辨識。

5. **Even/Odd Blend 非正交描述修正**
   觸發時機：實作 H3 時。把「bias 與 asymmetry **直接決定** H2/H3」改為更精確的「Even/Odd Blend 是產品層感知巨集參數，底層映射至 bias、asymmetry 與必要的 DC compensation，主要**影響**奇偶諧波分佈及其隨電平的變化，但**不假設**能獨立正交地控制 H2/H3」。順帶避免 Agent 做出 DC 漂移過大的簡陋 input-bias 實作。

6. **Phase B commit 兩階段狀態**
   觸發時機：Phase B 首輪。目前 Step 7 的 commit 在人類判斷產生前就寫 improved/regressed，時序矛盾。改為兩階段：首次 commit 標 `candidate` 或 `pending_review`（如 `[subtube-Voice-enhanced-Iter-03] softer dynamic bias | pending_review`），聆聽後再追加 decision commit 或 Git note 標 `accepted`/`rejected` + 人類回饋。至少首次 commit 不得提前寫 improved。

7. **R-Musicality「多次聆聽」最小定義**
   觸發時機：首次要標 `musically_preferred_deviation` 時。定義為：至少跨兩次獨立 listening pass，且至少在兩類 program material 上未出現明顯反效果。不需嚴格統計，但避免「同一分鐘連播兩次」被當成「多次確認」。

---

## 附錄 A：本次交付的乾聲測試訊號

以下四個檔案已隨本文件生成並交付，供你匯入 DAW、以 Saturn 2 的 Subtle Saturation / Subtle Tube 分別渲染後回傳：

| 檔案 | 用途 | 長度 |
|---|---|---|
| `01_tone_battery.wav` | 7 頻率（100/250/440/1000/2500/4000/8000 Hz）× 8 電平（-24 至 0 dBFS）序列，含前導校準 click | ~185 秒 |
| `02_log_sweep_moderate_-18dBFS.wav` | 20Hz–20kHz 對數掃頻，中等電平，供諧波解卷積分析 | ~12 秒 |
| `03_log_sweep_hot_-3dBFS.wav` | 同上，近滿電平 | ~12 秒 |
| `04_pink_noise_broadband_-12dBFS.wav` | 寬頻粉紅噪音，音色整體性 sanity check | ~6 秒 |

規格：48 kHz / 24-bit PCM。渲染建議：單頻段、Full Range、Solo，Wet/Mix 設 100%，並用 `render_manifest_template.csv` 記錄實際使用的 Drive/Amount、Oversampling 等設定值 — 這些設定值本身也是逆向工程時的重要線索，請盡量記錄完整。

若你的專案慣用 96 kHz，請告知，我會重新生成對應取樣率版本（目前 8kHz 測試音在 48kHz 取樣率下只能觀察到 Nyquist 以下的諧波，96kHz 可觀察更高階諧波）。
