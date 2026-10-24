#!/bin/sh
# specbench.sh: генерация 8B-A1B без черновика и с DSpark, одинаковые запросы, жадный выбор
B=~/llm/llama.cpp/build-cpu/bin/llama-server
M=~/llm/models/LFM2.5-8B-A1B-Q4_K_M.gguf
O=~/llm/agent/spec.txt; : > $O
systemctl --user stop llm-server
run() {
  name=$1; shift
  taskset -c 4-7 $B -m $M --host 127.0.0.1 --port 8090 -t 4 -c 4096 "$@" > ~/llm/agent/spec-$name.log 2>&1 &
  P=$!
  for i in $(seq 120); do curl -s 127.0.0.1:8090/health | grep -q ok && break; sleep 1; done
  for q in "Why is the sky blue? Explain in detail." "Как работает кеш процессора? Объясни подробно."; do
    curl -s 127.0.0.1:8090/v1/chat/completions -H "Content-Type: application/json" \
      -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$q\"}],\"max_tokens\":256,\"temperature\":0}" |
    python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('timings',{}); m=d['choices'][0]['message']; txt=(m.get('reasoning_content') or '')+(m.get('content') or ''); print('$name', t.get('predicted_n'), 'tok', round(t.get('predicted_per_second',0),2), 't/s', 'draft', t.get('draft_n'), 'accepted', t.get('draft_n_accepted'), '|', txt[:70].replace(chr(10),' '))" >> $O
  done
  kill $P; wait $P 2>/dev/null
}
run base
run dspark-q8 -md ~/llm/drafts/LFM2.5-8B-A1B-DSpark-Q8_0.gguf --spec-type draft-dspark
run dspark-q4 -md ~/llm/drafts/LFM2.5-8B-A1B-DSpark-Q4_K_M.gguf --spec-type draft-dspark
echo ALLDONE >> $O
