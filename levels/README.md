# Пакет рівнів

`pack.json` — рівні 1…150, згенеровані заздалегідь (`LevelGenerator` з перевіркою
механік працює десятки секунд на рівень — на телефоні це неприйнятно). Гра бере рівні
звідси (`scripts/core/level_pack.gd`); після 150-го — по колу з рівнів 103–150 з
переставленими кольорами. У кожного рівня збережено розв'язок; `tests/pack_test.gd`
(є в CI) перевіряє, що він проходить рівень, і що механіки — як задумано.

Перегенерувати (4 частини паралельно, потім злити):

```bash
for r in "1 60" "61 90" "91 120" "121 150"; do set -- $r
  godot --headless --script res://tests/build_pack.gd -- $1 $2 /tmp/pack_$1.jsonl &
done; wait
python3 -c "import json;print(json.dumps([json.loads(l) for f in ['1','61','91','121'] for l in open(f'/tmp/pack_{f}.jsonl')],separators=(',',':')))" > levels/pack.json
```
