git pull

cat hn_header.txt > hn.csv

for file in ./csv/hn_*.csv; do
  tail -n +2 $file >> hn.csv
done

mv hn.csv ~/csv

steampipe query "drop table if exists public.hn_items_all"

steampipe query "create table public.hn_items_all as select distinct on (id) * from csv.hn"

steampipe query "drop table if exists hn_scores_and_comments"

steampipe query "create table public.hn_scores_and_comments as ( select id::bigint, score, descendants as comments from hn_items_all where score::int > 10 order by time desc )"

steampipe query "with new_scores_and_comments as ( select *, (select score::text as new_score from hackernews_item i where i.id = sc.id::bigint),  (select descendants::text as new_comments from hackernews_item i where i.id = sc.id::bigint) from hn_scores_and_comments sc ) update hn_items_all a set score = n.new_score::text, descendants = n.new_comments::text from new_scores_and_comments n where a.id = n.id::text"


