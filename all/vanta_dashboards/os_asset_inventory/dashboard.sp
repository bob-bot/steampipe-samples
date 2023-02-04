dashboard "unsupported_os_versions" {
  title = "Employee Computers with Unsupported OS Versions"

  text {
    value = "The following list are for employees with unsupported OS versions, currently unmonitored by our auditing tools."
  }

  container {

    card {
      sql   = query.vanta_unmonitored_computer_count.sql
      width = 2
    }

  }

table {
    sql = query.vanta_list_unmonitored_computers.sql
  }

}

query "vanta_unmonitored_computer_count" {
  sql = <<-EOQ
    select
      count(*) as "value",
      'Unmonitored Computers' as label,
      case count(*) when 0 then 'ok' else 'alert' end as "type"
    from
        vanta_computer
    where
        unsupported_reasons is not null;
  EOQ
}



query "vanta_list_unmonitored_computers" {
  sql = <<-EOQ
    select
        owner_name,
        serial_number,
        agent_version,
        os_version,
        hostname,
        last_ping,
        case
            when os_version like 'Mac OS%' then 'Mac'
            when os_version like 'Windows%' then 'Windows'
            Else 'Linux'
        end as os_type,
        case
            when (unsupported_reasons -> 'unsupportedOsVersion')::boolean then 'OS version not supported'
            when (unsupported_reasons -> 'unsupportedOsType')::boolean then 'OS not supported'
        end as status
    from
        vanta_computer
    where
        unsupported_reasons is not null;
  EOQ
}
