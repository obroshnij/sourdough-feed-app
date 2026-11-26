# Sourdough science

Owner: `sourdough-scientist`. Plain-language science behind the starter sim and every safety rule. The numbers the game uses live in [`starter-simulation-spec.md`](starter-simulation-spec.md). Game copy may only make science claims that appear here.

**Confidence:** **high** = peer-reviewed data or consistent across authoritative sources. **medium** = established baking references agree, little lab data. **low** = anecdote, forum consensus, or my reasoning. Source keys are in §12. "Via summary" means the page could not be read in full (blocked or paywalled), so the claim rests on an abstract or search excerpt.

---

## 1. Safety summary (read this first)

| Sign | What it means | Action | Confidence |
|---|---|---|---|
| Gray, brown or black liquid on top (hooch) | Hunger. Mostly water and alcohol. | Pour off or stir in, then feed. Not dangerous. | high [KA23] |
| Sharp sour, vinegar, alcohol or acetone (nail polish) smell | Hunger or over-fermentation | Feed. Smell settles within a few feeds. | medium [PL], [TFL]; some dispute [SJa] |
| Flat, few bubbles, slow after the fridge or a few days away | Weakened, not dead | Feed once or twice a day at room temperature | high [KA18], [KA23], [PL] |
| Cheesy, sock or vomit smell in the first days of a **brand-new** starter | Normal early bacterial bloom | Keep feeding | medium [SJb] |
| Dry skin or crust on top or dried bits on the jar wall | Neglect. A spot where mold and discoloration tend to appear first. | Remove crust, feed, clean the jar | medium [KA23] |
| **Fuzzy growth of any color** (white, green, blue, black) | Mold | **Discard all of it.** Don't scrape and keep. | high [KA18], [USDA] |
| **Pink, orange or red tint or streaks** | Spoilage (often bacteria) | **Discard all of it.** | high [KA18], [KA23] |
| Flat, wrinkly white film, not fuzzy ("kahm yeast") | Sources disagree (§9.3) | **Conservative: discard if you are not sure.** | low |
| A musty, damp-basement smell | Can point to mold growth | Look closely. If any fuzz or color, discard. | low [EPA], [MVOC] |

Never present a starter with fuzz or pink, orange or red color as safe or fixable. Sourdough is food, not medicine: the game gives no health advice.

## 2. Who lives in a starter

- A starter is a stable community of **lactic acid bacteria (LAB)** and **yeasts** living on flour and water. **high** [L21], [DC14]
- LAB outnumber yeasts by roughly 10 to 100 times. Measured counts: LAB about 10^7 to 10^8.6 per gram, yeasts about 10^6 to 10^7.2. **high** [DC14]
- Yeasts make most of the gas (CO2) and alcohol. LAB make the acids (lactic and acetic). Heterofermentative LAB such as *Fructilactobacillus sanfranciscensis* also make some CO2. **high** (textbook; consistent with [G98])
- Some home starters also carry acetic acid bacteria. In 500 home starters, more of them correlated with a vinegar aroma and a slower rise. That link is correlational. **medium** [L21]
- Where you live matters little. How a starter is made and fed matters more. **medium** [L21]

**Temperature limits** (the basis of the sim's temperature curves):

| Organism | Tmin | Topt | Tmax | Source |
|---|---|---|---|---|
| *L. sanfranciscensis* (2 strains) | 3.0 to 4.1 °C | 32 to 33 °C | 41 °C | **high** [G98] |
| *Candida milleri* (now *Kazachstania humilis*) | about 8 °C | 27 °C | about 36 °C | **high** [G98] |
| Same pair in rye sourdough | | 28 °C (yeast), 32 °C (LAB) | | **high**, via summary [B04] |

- LAB growth stops near pH 3.8 to 3.9. Yeast growth was not limited by pH between 3.5 and 7. Acetate strongly inhibits that yeast. **high** [G98] (broth, not dough)
- Yeast dies at about 60 °C (140 °F), and starters likely suffer well below that. **medium** [KA18]
- Above about 32 °C the yeast falls behind the bacteria, so a very warm starter gets more sour and less lively. This is an inference from the cardinal temperatures. **medium**
- The cardinal temperature model with inflection [R93] fits growth that has a minimum, an optimum and a maximum. A single Q10 can't: it has no optimum. **high** [R93] (not fetched this session; standard predictive-microbiology reference)

## 3. Feeding, ratio, temperature and time

- **Ratio is dilution.** Feeding 1:1:1 leaves the old culture as a third of the jar. 1:5:5 leaves it as 1/11. Fewer starting cells mean a longer wait to peak. **high** [KA25], [PL]
- King Arthur test at about 78 °F (25.5 °C), mature starter: **high** [KA25]

| Ratio | 4 h | 8 h | 12 h |
|---|---|---|---|
| 1:1:1 | doubled | starting to fall | significant decrease |
| 1:2:2 | nearly doubled, not peaked | peaked, doubled | beginning to fall |
| 1:4:4 | noticeable rise | nearly doubled | fully doubled and peaked |

- 1:1:1 at about 78 °F "usually peaks in about 4 to 6 hours", with a range of 4 to 8 depending on health and kitchen temperature. It is ready to feed again after about 12 hours. **high** [KA25]
- Perfect Loaf: 1:5:5 (with 30% rye) at about 75 °F (24 °C) is ripe at about 10 h, just past ripe at 12 h, and "too far" by about 20 h. His 1:1:1 ripens in about 3 to 4 h. **medium** [PL]
- Warmer means faster. Perfect Loaf says ripening takes "roughly half as long in the tropics". The levers for speed are warmer water, more carried-over starter, whole grain flour and a warmer room. **medium** [PL]
- Bakers commonly target 24 to 26 °C (75 to 78 °F) for the starter. **medium** [PL]
- **Fridge:** a starter can live in the fridge on one feed a week, then needs a few room-temperature feeds before baking. **medium** [PL]. A starter left 8 weeks in the fridge grows dark hooch and may need two or more days of twice-daily feeds. **medium** [KA23]
- Missing a feed, or feeding off a strict 12 h schedule, "won't even come close to killing" a mature starter. **high** [KA18]. A starter can recover from a day or two without food. **medium** [PL]

## 4. Hydration

- Hydration = water ÷ flour × 100. 100% is the common default. "Stiff" starters run about 50 to 65%, "liquid" ones 125% or more. **medium** [PL]
- In a 28-day study, firm sourdoughs (dough yield 160, about 60% hydration) built **more total acid** (higher TTA, more lactic and acetic acid) than liquid ones (dough yield 280, about 180% hydration). The liquid ones carried more yeast and ended at a slightly lower pH. **high**, but only 4 Italian sourdoughs [DC14]
- The popular rule "stiff and cool means more acetic, wet and warm means more lactic" is only partly supported. One lab study found temperature had no significant effect on the lactic-to-acetic ratio, while fructose mattered most. **low to medium**, sources conflict [FQ92]
- Stiffer pastes trap gas and rise taller. Wetter starters show hooch sooner and more of it. **medium** (baker consensus; the sim magnitudes are tuned)

## 5. Flour types

- Whole grain flours (whole wheat, rye) speed fermentation. **medium** [PL]
- Rye raises acetic acid. **medium** [PL]
- Different flours select for different mature communities. **medium**, via summary [SUC]
- Rye has little functional gluten, so rye starters rise less and crack or pit instead of forming a smooth dome. A slight pinkish-gray tinge from rye is not the same as pink streaks. **medium** (baking references; [SUC] summary notes rye pink tinge from blog sources, low)
- Exact speed and sourness multipliers per flour have no clean source. The sim marks them as tuned.

## 6. Activity: rise, peak, fall, bubbles, smell, texture, acidity

- **Cycle:** after feeding there is a short quiet phase, then bubbles appear at the glass, the starter rises and domes, the dome flattens (the peak), then it falls and leaves streaks on the glass above. **high** [PL], [KA25]
- **Peak signs:** a domed or just-flattening top, many bubbles at the surface, a web-like structure, and a sour, vinegary smell with some sweetness. **medium** [PL]
- **Past peak:** streaks on the jar sides, a collapsing center, then a heavy acid smell, small bubbles on top and possibly hooch. **medium** [PL]
- **Doubling** is the common readiness rule of thumb. A mature 1:1:1 starter roughly doubles. **high** [KA25]
- The float test gives false positives. **medium** [PL]
- **Acidity:** a ripe starter typically sits around pH 3.5 to 4.3. The study above measured 4.2 to 4.3 after a full refresh cycle. **medium** [DC14] for the measured range; the sim's pH display is approximate.
- **Smells over a cycle:** wet flour right after feeding, then yeasty, fruity and yogurt-like, then tangy at peak, then sharper, boozy and acetone-like as it goes hungry. **medium** [PL], [TFL]

## 7. Maturity

- New (spontaneous) starters go through a succession. Enterobacteriaceae and other bacteria dominate the first days, then a "relay" of lactic acid bacteria, and finally acid-tolerant lactobacilli. **medium to high**, via summary [SUC]
- Bakers consider a starter mature when rise and pH are stable, typically after 7 to 14 days. **medium** [SUC], [KA18] ("6 to 10 days" to create one)
- Days 2 to 3 often bring a "false rise" from a bacterial bloom, with cheesy, sock or vomit smells that fade by about day 4. This is normal. **medium** [SJb]
- A young starter "hasn't yet developed the defenses" of a mature one. **medium** [KA18]
- Community selection happens once per feed-and-grow cycle, and a bigger dilution means more doublings per cycle. The sim uses this to weight maturity. **low** (my reasoning from backslopping practice, not a measured result)
- "Older starters make better bread" and "seasoned" starters are folklore. There is no measured benefit beyond stabilization. **low**

## 8. Common problems and recovery

| Problem | Cause | Fix | Confidence |
|---|---|---|---|
| Hooch | Food used up. Alcohol and water separate out. Darker the longer it sits. | Pour off (especially if more than about half an inch or very dark) or stir in. Feed. A thin sheen: 1 or 2 feeds. A lot, or dark: often 2 or more days of twice-daily feeds. | high [KA23] |
| Acetone or nail polish smell | Usually hunger after the peak | Feed more often or at a bigger ratio. One source says it can persist even when well fed. | medium [TFL]; dissent [SJa] |
| Sluggish after the fridge | Cold, weakened, acidic culture | One or two room-temperature feeds | medium [PL] |
| Sluggish after neglect | Starvation weakens it | Feed once or twice a day. It recovers. | high [KA18], [KA23] |
| Rises then collapses fast, very sour | Too warm, or fed too rarely for the ratio | Cooler spot, bigger ratio | medium [PL] |
| Brand-new starter smells bad on days 2 to 4 | Early bacterial bloom | Keep feeding | medium [SJb] |

Truly ending a mature starter takes heat (near 60 °C), mold, or spoilage. Hunger alone does not. **medium** [KA18]

## 9. Mold and contamination

### 9.1 What is known
- Neglect "long enough" leads to mold or "signs of being overtaken by bad bacteria". **high** [KA18]. One King Arthur example: a stiff starter left out for two weeks at room temperature had to be thrown out. **medium** [KA18]
- Mold "can appear in various colors and is typically fuzzy". **high** [KA18]
- Orange or pink tint or streaks, on the starter or on dried crust on the container walls, mean discard. **high** [KA18], [KA23]
- In soft, high-moisture foods, mold can reach below the surface, and bacteria may grow along with it. USDA advises discarding such foods rather than cutting the mold away. A starter is a soft, high-moisture food. **high**, via summary [USDA]
- Mold can grow in the refrigerator, slowly. **medium**, via summary [USDA]
- Mold growth is linked to musty and earthy volatile compounds (such as 1-octen-3-ol and geosmin). A musty odor suggests mold is growing. **medium** [EPA], [MVOC]. Some fungi give off volatiles before they are visible. Whether that applies to starters has not been measured. **low** [MVOC]

### 9.2 What the game does with it
- In the game, mold comes only from long neglect at room temperature, with a dry surface speeding it up. That is the most common real cause. In real life, mold can also appear on brand-new starters, from dirty jars or tools, or with no warning at all. The game simplifies. It never claims that warnings always come first in real life.
- The game's warnings (musty smell, dry skin, thick dark hooch, a flat, quiet starter) are real risk signs. Not one of them shows fuzz or color, because those always mean discard.
- Exact days to mold are not predictable in real life. The sim's timings are tuned for game.

### 9.3 Disputed: kahm yeast and films
- Many baking blogs say a flat, white, wrinkly film (kahm yeast) is harmless and can be scraped off. **low** [KAHM]
- Mold-safety guidance for soft foods says discard [USDA], and a film is easy to confuse with early mold.
- **Conservative recommendation (used by the game):** if you are not sure it is harmless, discard. The game does not model kahm yeast at all.

### 9.4 Normal vs contamination

| Looks or smells like | Normal hunger sign | Discard |
|---|---|---|
| Clear, gray, brown or black liquid on top | ✓ (hooch) | |
| Alcohol, acetone, vinegar, very sour | ✓ | |
| Gray tinge on the surface under hooch | ✓ | |
| Cream or beige streaks on the glass above the starter | ✓ (residue from the peak) | |
| Dry skin or crust | Not mold itself. Remove it and feed. | If it shows any fuzz or pink or orange |
| Musty, damp smell | Warning: look closely | If any fuzz or color is present |
| Fuzzy spots, any color | | ✓ |
| Pink, orange or red tint or streaks | | ✓ |
| Flat white film, unsure what it is | | ✓ (conservative) |

## 10. Established vs folklore

| Claim | Verdict | Confidence |
|---|---|---|
| Hooch means the starter is spoiled | **False.** Hooch is a hunger sign. | high [KA23] |
| You must feed exactly every 12 hours | **False.** Mature starters tolerate missed feeds. | high [KA18] |
| Mold can be scraped off and the starter kept | **False and unsafe.** Discard. | high [KA18], [USDA] |
| Local air or water gives each city's sourdough its character | **Mostly false.** Little geographic pattern; how it is made and fed matters more. | medium [L21] |
| Warmer starters ferment faster | **True** up to about 30 to 32 °C | high [G98], [PL] |
| Whole grain and rye speed up fermentation | **True** | medium [PL] |
| Stiff and cool means more sour (acetic); wet and warm means milder | **Partly.** Firm builds more total acid; the temperature effect is disputed. | low to medium [DC14], [FQ92] |
| Acetone smell always means hunger | **Usually**, but not always | medium [TFL], [SJa] |
| The float test proves readiness | **Unreliable** | medium [PL] |
| Older starters are better | **Unproven folklore** | low |

## 11. What the game simplifies (honest list)

- One acid value instead of separate lactic and acetic acid.
- No acetic acid bacteria, kahm yeast or tool contamination. Mold comes from neglect only.
- One constant temperature per location. No day and night swings.
- Mold timing is a game rule built on real risk factors, not a forecast.
- All speed, height and sourness magnitudes not named in §3 are tuned for game. Their direction follows this document.

## 12. Sources

| Key | Source |
|---|---|
| [G98] | Gänzle MG, Ehmann M, Hammes WP (1998). Modeling of growth of *Lactobacillus sanfranciscensis* and *Candida milleri* in response to process parameters of sourdough fermentation. *Appl Environ Microbiol* 64(7):2616-2623. https://pmc.ncbi.nlm.nih.gov/articles/PMC106434 |
| [B04] | Brandt MJ, Hammes WP, Gänzle MG (2004). Effects of process parameters on growth and metabolism of *L. sanfranciscensis* and *Candida humilis* during rye sourdough fermentation. *Eur Food Res Technol* 218:333-338. Via summary. |
| [R93] | Rosso L, Lobry JR, Flandrois JP (1993). An unexpected correlation between cardinal temperatures of microbial growth highlighted by a new model. *J Theor Biol* 162:447-463. Standard reference, not fetched this session. |
| [L21] | Landis EA, Oliverio AM, McKenney EA, et al. (2021). The diversity and function of sourdough starter microbiomes. *eLife* 10:e61644. https://elifesciences.org/articles/61644 |
| [DC14] | Di Cagno R, Pontonio E, Buchin S, et al. (2014). Diversity of the lactic acid bacterium and yeast microbiota in the switch from firm- to liquid-sourdough fermentation. *Appl Environ Microbiol* 80(10):3161-3172. https://pmc.ncbi.nlm.nih.gov/articles/PMC4018931 |
| [FQ92] | 1992 study modulating the lactic-to-acetic fermentation quotient (0.9 to 4.5) with temperature, dough yield and fructose, using one *L. brevis* strain. https://link.springer.com/doi/10.1007/BF01202806 Via summary. |
| [SUC] | Spontaneous sourdough succession studies: https://pmc.ncbi.nlm.nih.gov/articles/PMC3837820 and "Sourdough starters exhibit similar succession patterns but develop flour-specific climax communities", *PeerJ* (2023), https://peerj.com/articles/16163. Via summary. |
| [KA25] | King Arthur Baking (2025-03-13). Sourdough feeding ratios. https://www.kingarthurbaking.com/blog/2025/03/13/sourdough-feeding-ratios |
| [KA23] | King Arthur Baking (2023-08-28). Sourdough starter black liquid. https://www.kingarthurbaking.com/blog/2023/08/28/sourdough-starter-black-liquid |
| [KA18] | King Arthur Baking (2018-03-09). Sourdough starter troubleshooting. https://www.kingarthurbaking.com/blog/2018/03/09/sourdough-starter-troubleshooting-2 |
| [PL] | The Perfect Loaf. Sourdough starter maintenance routine (article and author replies). https://www.theperfectloaf.com/sourdough-starter-maintenance-routine/ |
| [USDA] | USDA FSIS. Molds on Food: Are They Dangerous? https://www.fsis.usda.gov/sites/default/files/media_file/2021-02/Molds_on_Food.pdf Via summary (the page returned 403). |
| [EPA] | US EPA. What does mold smell like? https://www.epa.gov/node/217605 Via summary. |
| [MVOC] | CDC-hosted MVOC study (musty and earthy compounds), https://stacks.cdc.gov/view/cdc/199194 ; review in *J Japan Assoc Odor Environ* 43(3):184, https://www.jstage.jst.go.jp/article/jao/43/3/43_184/_article. Via summary. |
| [SJa] | The Sourdough Journey. My sourdough starter smells like acetone. https://thesourdoughjourney.com/my-sourdough-starter-smells-like-acetone/ Via summary. |
| [SJb] | The Sourdough Journey. The first 10 days of a new sourdough starter (PDF). https://thesourdoughjourney.com/wp-content/uploads/2023/11/TSJ-The-First-10-Days-of-a-New-Sourdough-Starter.pdf Via summary. |
| [TFL] | The Fresh Loaf forum threads on acetone smell, e.g. https://www.thefreshloaf.com/comment/481927. Community consensus, low authority. |
| [KAHM] | Kahm yeast guidance: Brød & Taylor starter FAQ https://brodandtaylor.com/blogs/recipes/starter-creation-faq ; Cultures for Health https://www.culturesforhealth.com/white-film-cultured-vegetables-mold. Via summary, low authority. |
