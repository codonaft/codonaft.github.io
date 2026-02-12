---
layout: page
navbar-title: 💜 Поддержать
title: Поддержать независимого разработчика СПО
feature-img: "assets/img/keyboard-background.webp"
feature-title: <span class='no-wrap'>Свободное ПО</span> — это <span class='no-wrap'><u>причина</u> того,</span> <span class='no-wrap'>почему я выбрал <u>карьеру</u></span> разработчика <span class='no-wrap'>программного обеспечения</span>
permalink: /ru/sponsor/
lang-en-uri: /sponsor/
---
{% include navbar_selection.html %}
{% include sponsor.html %}

Занимался
{% include span_with_tooltip.html body="разработкой ПО" tooltip="<span class='no-wrap'>C++ / GameDev</span> → <span class='no-wrap'>🦀 Rust / Highly-Loaded Backend</span>" %}
для [опыта](https://www.linkedin.com/in/{{ site.theme_settings.linkedin }}).
Вернулся в разработку <span class='no-wrap'>[свободного](https://github.com/alopatindev) ПО</span>, чтобы сделать этот мир лучше!

Твоя поддержка позволяет мне <span class='no-wrap'>продолжать ❤️</span>

<!-- div style="display: flex; justify-content: center; padding-bottom: 2rem; margin-top: 0">
  <div class="example" style="max-width: 40rem">
    <h3 style="text-align: center">Как поддержать:</h3>
    <ul style="margin-bottom: 0">
      <li>поделиться этой страницей в соцсетях:</li>
    </ul>
    {% include share_buttons.html no_text=true %}
    <ul>
      <li>нажать ⭐ на страницах понравившихся <a href="https://github.com/alopatindev">проектов</a>
        <ul>
          <li>поделиться проектами со своими друзьями/коллегами</li>
          <li>помочь конкретно мелкому проекту <a href="https://github.com/cargo-limit/cargo-limit#support"><img style="display: inline-block; vertical-align: middle; width: 1.4rem; height: 1.4rem" src="/assets/img/cargo-limit.svg">cargo-limit</a></li>
        </ul>
      </li>
      <li class="padding-top-small">общими донатами на всё что я {% include span_with_tooltip.html body="произвожу" tooltip="Разработку свободного ПО <span class='no-wrap'>и периодического</span> <span class='no-wrap'>выпуска контента</span>" %}:</li>
    </ul>
  </div>
</div -->

<div class="donation-container" style="margin-top: 4rem">
  <div class="grid-container">
    <div class="grid-item">
      <p style="margin-bottom: 0.7em"><a href="bitcoin:{{ site.theme_settings.btc }}?amount=0.0002">{% include icons/bitcoin.svg %}</a></p>
      <p style="margin-bottom: 0"><strong>Bitcoin</strong> (BTC):</p>
      <p style="margin-bottom: 0"><code class="language-plaintext highlighter-rouge">{{ site.theme_settings.btc }}</code></p>
      <p><a href="https://zapmeacoffee.com/{{ site.theme_settings.nostr.npub }}" target="_blank">⚡</a><a href="https://zapper.nostrapps.org/zap?id={{ site.theme_settings.nostr.npub }}&amount=10000" target="_blank">Lightning</a>: <code class="language-plaintext highlighter-rouge">{{ site.theme_settings.lightning }}</code></p>
    </div>
    <div class="grid-item">
      <p>{% include icons/tron.svg %}</p>
      <p><strong>TRON</strong> (TRX, USDT-TRC20, etc.):</p>
      <p><code class="language-plaintext highlighter-rouge">TRaiGAmtWpPxLF6py6apfSNKKPjpUXAY57</code></p>
    </div>

    <div class="grid-item">
      <p>{% include icons/ton.svg %}</p>
      <p><strong>Toncoin</strong> (TON):</p>
      <p><code class="language-plaintext highlighter-rouge">EQA3WT7EB3QS3PsxOILbbhKHvqHTxtwkfJWcdZqvuQ8WfkyK</code></p>
    </div>

    <div class="grid-item">
      <p><a href="ethereum:{{ site.theme_settings.eth }}?value=0.004e18">{% include icons/ethereum.svg %}</a></p>
      <p><strong>Ethereum</strong> (ETH, DAI, etc.):</p>
      <p><code class="language-plaintext highlighter-rouge">{{ site.theme_settings.eth }}</code></p>
    </div>

    <div class="grid-item">
      <p><a href="zcash:{{ site.theme_settings.zec }}?amount=0.25">{% include icons/zcash.svg %}</a></p>
      <p><strong>Zcash</strong> (ZEC):</p>
      <p><code class="language-plaintext highlighter-rouge">{{ site.theme_settings.zec }}</code></p>
    </div>

    <div class="grid-item">
      <p><a href="litecoin:{{ site.theme_settings.ltc }}?amount=0.16">{% include icons/litecoin.svg %}</a></p>
      <p><strong>Litecoin</strong> (LTC):</p>
      <p><code class="language-plaintext highlighter-rouge">{{ site.theme_settings.ltc }}</code></p>
    </div>

    <!-- div class="grid-item">
      <a href="https://www.patreon.com/{{ site.theme_settings.patreon }}" alt="Стать патроном" title="Стать патроном" rel="noopener noreferrer" target="_blank"><img style="width: 170pt; height: 40pt" src="/assets/img/donate-with-patreon.svg"></a>
    </div>

    <div class="grid-item">
      <a href="https://opencollective.com/alopatindev" alt="Donate with OpenCollective" rel="noopener noreferrer" target="_blank">{% include icons/opencollective.svg %}</a>
      <p><strong>Open Collective</strong></p>
    </div>

    <div class="grid-item">
      <a href="https://ko-fi.com/P5P3R40NX" alt="Support me on Ko-fi" rel="noopener noreferrer" target="_blank">{% include icons/donate-with-kofi.svg %}</a>
    </div>

    <div class="grid-item">
      <a href="https://paypal.me/alopatindev" alt="Поддержать с помощью PayPal" title="Поддержать с помощью PayPal" rel="noopener noreferrer" target="_blank">{% include icons/donate-with-paypal.svg %}</a>
    </div>

    <div class="grid-item">
      <a href="https://liberapay.com/alopatindev" alt="Поддержать с помощью Liberapay" title="Поддержать с помощью Liberapay" rel="noopener noreferrer" target="_blank">{% include icons/liberapay.svg %}</a>
      <p><strong>Liberapay</strong></p>
    </div -->
  </div>
</div>

<p>
  <div style="display: flex; justify-content: center">
    <div class="esoteric-crypto"><details><summary markdown="span">Эзотерической криптой 💎🟡🌚</summary>
      <ul>
        <li><strong>AuroraCoin</strong> (AUR): <code class="language-plaintext highlighter-rouge">AMf189Ap4RqQ71L9YWXE9ZBm8GFTnYSTST</code></li>
        <li><strong>Binance coin</strong> (BNB): <code class="language-plaintext highlighter-rouge">0xff3c912b69d6fc8b0e9bc7bb7ed897557ef5d28f</code></li>
        <li><strong>BitcoinCash</strong> (BCH): <code class="language-plaintext highlighter-rouge">qzpewzlsypp5ld2udvfxxw4yhxmlvzy5ku5rnwvj3e</code></li>
        <li><strong>BitcoinGold</strong> (BTG): <code class="language-plaintext highlighter-rouge">GTp7xTfsCSgMqcniS6AVdFhi1L3Nzh7wvJ</code></li>
        <li><strong>BlockChainCoinX</strong> (XCCX): <code class="language-plaintext highlighter-rouge">XNdPhpWZJjyFFA93pCtvENHeWwiDDK1EHZ</code></li>
        <li><strong>Blocknet</strong> (BLOCK): <code class="language-plaintext highlighter-rouge">BnpacNjCfFWQnKEkJgA2LEY5nGfZyd7q3r</code></li>
        <li><strong>Dash</strong> (DASH): <code class="language-plaintext highlighter-rouge">XgW9K6AVqfjP9u9cTvHZBLj51NP6eRxEqA</code></li>
        <li><strong>DeepOnion</strong> (ONION): <code class="language-plaintext highlighter-rouge">DVMVucBGRbj2Uv9QwQj83MRksQAofhTybv</code></li>
        <li><strong>DigiByte</strong> (DGB): <code class="language-plaintext highlighter-rouge">D7a9ysrXXuhqhkxcSweeMvuB57bu1YbNPd</code></li>
        <li><strong>Dogecoin</strong> (DOGE): <code class="language-plaintext highlighter-rouge">D6hkWmCYgbia6oEcuYCdfsPxpXSyTc2DdU</code></li>
        <li><strong>Emercoin</strong> (EMC): <code class="language-plaintext highlighter-rouge">EKyvkQt5CvLtNdACvATdpedmGAhRqHnsm3</code></li>
        <li><strong>Ethereum Classic</strong> (ETC): <code class="language-plaintext highlighter-rouge">0x4822d96683ac11cdac6dc3389a22076164b30d09</code></li>
        <li><strong>EverGreenCoin</strong> (EGC): <code class="language-plaintext highlighter-rouge">ERcmx7nxHG3s1o7hnC3aQKBU3scJEtDuth</code></li>
        <li><strong>Flux</strong> (FLUX): <code class="language-plaintext highlighter-rouge">t1cvr66T2uL6sZgp3HcLMjYUxedVs9aHJzT</code></li>
        <li><strong>GuapCoin</strong> (GUAP): <code class="language-plaintext highlighter-rouge">GNpUxGUxoMi8VoXm7Peq31fskFSkq8Ahfg</code></li>
        <li><strong>Hivecoin</strong> (HVQ): <code class="language-plaintext highlighter-rouge">HRCsmcRFFgDHLeUwJgKxEoKwuHNgdSkLoe</code></li>
        <li><strong>Komodo</strong> (KMD): <code class="language-plaintext highlighter-rouge">RKb2vZewxuNMMuSVinz4mbRZn9GJTyDc59</code></li>
        <li><strong>Monero</strong> (XMR): <code class="language-plaintext highlighter-rouge">45H6MXry6cqS4zwsPBsotx8dBSB9zvnnnbxdkqrCmYH2Rh1hsDKBsjoP67Er966wWBD7awbubMEWx1WfSaRyKFgVCjEKunT</code></li>
        <li><strong>NameCoin</strong> (NMC): <code class="language-plaintext highlighter-rouge">N66EC4gqfjrw6k64URsYX3NDzmESFuGXL6</code></li>
        <li><strong>Novacoin</strong> (NVC): <code class="language-plaintext highlighter-rouge">4ZPNP6hr5GWdSnvxYvswtfCnMUokrtyWP7</code></li>
        <li><strong>PIVX</strong> (PIVX): <code class="language-plaintext highlighter-rouge">DPLE8djj5cZpXmHn361G56Q3m4Wcygx96k</code></li>
        <li><strong>Peercoin</strong> (PPC): <code class="language-plaintext highlighter-rouge">PDUbcDVQgDkrqTidtUdrRMt5FVawnutnzr</code></li>
        <li><strong>PostCoin</strong> (POST): <code class="language-plaintext highlighter-rouge">PNPn16AU9Jp6MX3CLEMitCX4XX3w5BdDvM</code></li>
        <li><strong>Qtum</strong> (QTUM): <code class="language-plaintext highlighter-rouge">QMMvbdKcaAmeThHsXjWUUTYFMB5Si6cZaS</code></li>
        <li><strong>Radiant</strong> (RXD): <code class="language-plaintext highlighter-rouge">19VwKwXYQkMuLGykrPW12njve1xEnAH2cz</code></li>
        <li><strong>Raptoreum</strong> (RTM): <code class="language-plaintext highlighter-rouge">RGLagv2pAjJ3rfoUC4kJFtVw5ogRRBNYYq</code></li>
        <li><strong>Ravencoin</strong> (RVN): <code class="language-plaintext highlighter-rouge">R9WVSimFV1HnbrLGo8zzQiaNWwnwt7Y3Ui</code></li>
        <li><strong>ReddCoin</strong> (RDD): <code class="language-plaintext highlighter-rouge">Rt4NQRZepSm9wERw4ZhgQaM1PHzschzaXE</code></li>
        <li><strong>SmartHoldem</strong> (STH): <code class="language-plaintext highlighter-rouge">SUxHKRsZC9Jv3T3zxPoq9Sq5pMpT9me4rg</code></li>
        <li><strong>Vericoin</strong> (VRC): <code class="language-plaintext highlighter-rouge">VKfmNKqgcwHk9CgPbsCnWJH2crVVq47g75</code></li>
        <li><strong>Vertcoin</strong> (VTC): <code class="language-plaintext highlighter-rouge">Vh6GcgW2DQ7ZGpHhbt44Ru482YZFNcVXuX</code></li>
        <li><strong>WAVES</strong> (WAVES): <code class="language-plaintext highlighter-rouge">3PJwsjYtoBujKM1SDxFZJZfU46C88vvsXrA</code></li>
        <li><strong>eXperience</strong> (XP): <code class="language-plaintext highlighter-rouge">PJGQhytWiPsQebgt1xAJwTdiMF333S4Eje</code></li>
      </ul>
    </details></div>
  </div>
</p>

<h3 style="text-align: center; padding-top: 1rem">Благодарю за поддержку! 🙏🏼</h3>
<br>

---

{::options parse_block_html="true" /}
<div class="faq">
## FAQ

### Зачем спонсировать свободное ПО? Что не так с традиционными бизнесами?
Традиционные компании активно способствуют [метакризису](https://en.wikipedia.org/wiki/Polycrisis#Metacrisis), в котором мы живем.

<details><summary markdown="span">Больше деталей! 👁️</summary>
Проприетарное ПО, которое они создают, находится на пике [различных](https://youtu.be/NfiIXooD77s)
[нездоровых](https://github.com/Alexlittle4/Zoom-violates-users-privacy#readme)
[манипулятивных](https://www.reddit.com/r/paypal/comments/1hfg3jr/paypal_refuses_to_change_to_local_currency_at/)
<a href="/ru/ideas-for-foss-projects/?t=975" target="_blank">практик</a>.

Этими «решениями» уже стало невыносимо пользоваться, по крайней
[мере](https://github.com/jswanner/DontF-WithPaste#readme)
[без](https://github.com/ungoogled-software/ungoogled-chromium#readme)
[кучи](https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies#readme)
[тяжеловесных](https://github.com/dessant/buster#readme)
[костылей](https://github.com/nang-dev/hover-paywalls-browser-extension#readme)!

[Они](https://youtu.be/7LqaotiGWjQ?t=3426s) слишком зациклились
на капиталистических [ценностях](https://www.snopes.com/fact-check/sony-patent-mcdonalds) и самозащите,
едва ли оставляя возможность длительно предоставлять *реальные* инновации и позитивные изменения качества жизни.

Типичные «новые» программные продукты на самом деле не новые — это в основном слепое копирование идей сомнительного качества.
По-настоящему новое ПО должно пытаться привносить инновации, которые
[двигают](https://nosotros.app/naddr1qq2njmtfduekvan3wey4zdmjv4n4x4txxdkkjqgcwaehxw309ahx7um5wghxxmmydahxzen59e3k7mgpzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgqg5waehxw309aex2mrp0yhxgctdw4eju6t0qgswls4kuk2gpu89tny8c6d0q6mdrggl5f0ya226gwv833qhn8zncxgrqsqqqa28dkzfll)
общество в позитивном направлении!

Когда же компании делают что-то, что *кажется* здоровым и новаторским
— [вероятно](https://en.wikipedia.org/wiki/Contributor_License_Agreement#Relicensing_controversy)
[это](https://calyxos.org/news/2025/06/11/android-16-plans/)
[ненадолго](https://cointelegraph.com/news/ton-blockchain-freezes-2-6b-worth-of-inactive-tokens).
</details>

Независимые разработчики свободного ПО могут сделать кое-что получше. Я ориентируюсь на следующие **принципы**:

- **Минимизация отвлечения внимания**
    - 🧠 ПО должно быть [экологичным](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4183915/) [ментально](https://youtu.be/Iy7i9ru7HB8?t=15s) и понятным интуитивно; оно никогда не должно намеренно <a href="/how-to-take-notes-like-a-programmer/#whats-the-point" target="_blank">прерывать</a> творческий процесс!
    - 🚫 больше никаких трат ментальных ресурсов на всплывающие ловушки, [{% include span_with_tooltip.html large="true" body="имитацию" tooltip="Капча бесполезна: боты в основном уже <span class='no-wrap'>неотличимы от людей.</span><br>Время сменить стратегию: потенциально спамную нагрузку нужно превращать в полезные вычисления, не причиняя вред ни пользователям, ни окружающей среде, ни даже бизнесам!" %}](https://futurism.com/ai-model-turing-test) CAPTCHA, внезапные нежелательные туториалы, абсурдно подробные [{% include span_with_tooltip.html large="true" body="руководства" tooltip="Хватит плодить устаревшие и переусложненные UI!<br>Хорошо спроектированное и интуитивно-понятное ПО с ИИ <i>в идеале</i> вообще не нуждается в документации!" %}](https://web.archive.org/web/20250806061741/https://www.facebook.com/help/124895950923762) и так далее!
- **Суверенитет данных**
    - 🔒 *ты* владеешь своими [данными](https://martin.kleppmann.com/2019/10/23/local-first-at-onward.html), а не третьи лица!

{::options parse_block_html="false" /}
</div>

{% include share_buttons.html heart_only="true" %}
<br>
