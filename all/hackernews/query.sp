query "mentions" {
  sql = <<EOQ
    with names as (
      select
        unnest( $1::text[] ) as name
    ),
    counts as (
      select
        name,
        (
          select
            count(*)
          from
            hn_items_all
          where
            title ~* name
            and (extract(epoch from now() - time::timestamptz) / 60)::int between symmetric $2 and $3
        ) as mentions
        from
          names
    )
    select
      replace(name, '\', '') as name,
      mentions
    from
      counts
    where
      mentions > 0
    order by 
      mentions desc
  EOQ
  param "names" {}
  param "min_minutes_ago" {}
  param "max_minutes_ago" {}
}

query "submission_times" {
  sql = <<EOQ
    select
      id,
      to_char(time::timestamptz, 'MM-DD hHH24') as time,
      title,
      url,
      score,
      case
        when descendants = '<null>' then ''
        else descendants
      end as comments
    from 
      hn_items_all
    where
      by = $1
    order by
      score::int desc
  EOQ
  param "hn_user" {}

}

query "submission_days" {
  sql = <<EOQ
    select
      to_char(time::timestamptz, 'MM-DD') as day,
      count(to_char(time::timestamptz, 'MM-DD'))
    from 
      hn_items_all
    where
      by = $1
      and time::timestamptz > now() - ($2 || ' day')::interval
    group by 
      day
    order by
      day desc
  EOQ
  param "hn_user" {}
  param "since_days_ago" {}
}

query "domains" {
  sql = <<EOQ
    with domains as (
      select
        url,
        substring(url from 'http[s]*://([^/$]+)') as domain
    from 
      hn_items_all
    where
      url != '<null>'
    ),
    avg_and_max as (
      select
        substring(url from 'http[s]*://([^/$]+)') as domain,
        avg(score::int) as avg_score,
        max(score::int) as max_score,
        avg(descendants::int) as avg_comments,
        max(descendants::int) as max_comments
      from
        hn_items_all
      group by
        substring(url from 'http[s]*://([^/$]+)')
    ),
    counted as (
      select 
        domain,
        count(*)
      from 
        domains
      group by
        domain
      order by
        count desc
    )
    select
      a.domain,
      c.count,
      a.max_score,
      round(a.avg_score, 1) as avg_score,
      a.max_comments,
      round(a.avg_comments, 1) as avg_comments
    from
      avg_and_max a
    join
      counted c 
    using 
      (domain)
    where
      c.count > 5
    order by
      max_score desc
  EOQ
}

query "domain_detail" {
  sql = <<EOQ
    with items_by_day as (
      select
        to_char(time::timestamptz, 'MM-DD') as day,
        substring(url from 'http[s]*://([^/$]+)') as domain
    from 
      hn_items_all
    where
      substring(url from 'http[s]*://([^/$]+)') = $1
    )
    select 
      day,
      count(*)
    from 
      items_by_day
    group by
      day
    order by
      day
  EOQ
  param "domain" {}
}

query "source_detail" {
  sql = <<EOQ
    select
      h.id as link,
      to_char(h.time::timestamptz, 'MM-DD hHH24') as time,
      h.score,
      h.url,
      ( select count(*) from hn_items_all where url = h.url ) as occurrences,
      h.title
    from
      hn_items_all h
    where 
      h.url ~ $1
    order by
      h.score::int desc
  EOQ
  param "source_domain" {}
}

query "people" {
  sql = <<EOQ
    with hn_users_and_max_scores as (
      select 
        by,
        max(score::int) as max_score
      from
        hn_items_all
      group by
        by
      having
        max(score::int) > 200
    ),
    hn_info as (
      select 
        h.by,
        ( select count(*) from hn_items_all where by = h.by ) as stories,
        ( select sum(descendants::int) from hn_items_all where descendants != '<null>' and by = h.by group by h.by ) as comments
      from hn_users_and_max_scores h 
    ),
    plus_gh_info as (
      select
        h.*,
        g.html_url as github_url,
        case 
          when g.name is null then ''
          else g.name
        end as gh_name,
        g.followers::int as gh_followers,
        g.twitter_username
      from
        hn_info h
      join
        github_user g
      on 
        h.by = g.login
      order by
        h.by
    ) 
    select
      p.by,
      u.karma,
      p.stories,
      p.comments,
      p.github_url,
      p.gh_followers,
      case 
        when p.twitter_username is null then ''
        else 'https://twitter.com/' || p.twitter_username
      end as twitter_url
    from
      plus_gh_info p 
    join
      hackernews_user u 
    on 
      p.by = u.id
    order by
      karma desc
   EOQ
}

query "posts" {
  sql = <<EOQ
    select 
      id as link,
      to_char(time::timestamptz, 'MM-DD hHH24') as time,
      title,
      by,
      score::int,
      descendants::int as comments,
      url,
      case
        when url = '' then ''
        else substring(url from 'http[s]*://([^/$]+)')
      end as domain
    from
      hn_items_all
    where 
      score != '<null>'
      and descendants != '<null>'
    order by 
      score desc
    limit 100
  EOQ
}

query "urls" {
  sql = <<EOQ
    select
      url,
      to_char(time::timestamptz, 'MM-DD hHH24') as time,
      count(*) as occurrences,
      sum(score::int) as score,
      sum(descendants::int) as comments
    from
      hn_items_all
    where
      url != '<null>'
    group by
      url,
      time,
      score
    order by
      score desc
    limit 
      500
  EOQ
}

query "update_scores_and_comments" {
  sql = <<EOQ
    update 
      hn_items_all a 
    set 
      score = new_sc.new_score, 
      descendants = new_sc.new_descendants 
    from 
      csv.new_sc 
    where new_sc.id = a.id
  EOQ
}
