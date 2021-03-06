class SubmissionsImporter

  require 'bigquery-client'

  def self.bigquery_init
    opts = YAML.load_file("#{Rails.root}/config/bigquery.yml")
    BigQuery::Client.new(opts['config'])
  end

  def self.attributes_list(schema)
    attribute_names = []

    schema['fields'].each do |field|
      attribute_names << field['name']
    end

    attribute_names
  end

  def self.attribute_val(row, attributes, name)
    row['f'][attributes.index(name)]['v']
  end

  def self.create_submissions(data, test_type)
    data.each do |row|
      submission = Submission.where('DATE(created_at) = ? AND ip_address = ? AND test_type = ?', Date.parse(row['UTC_date_time']), row['client_ip_numeric'], test_type).first_or_initialize

      next if submission.persisted?

      submission.from_mlab           = true
      submission.completed           = true
      submission.ip_address          = row['client_ip_numeric']
      submission.created_at          = row['UTC_date_time']
      submission.address             = row['city']
      submission.area_code           = row['area_code']
      submission.zip_code            = row['postal_code']
      submission.hostname            = row['client_hostname']
      submission.latitude            = row['client_latitude']
      submission.longitude           = row['client_longitude']
      submission.provider            = Submission.provider_mapping(submission.get_provider)
      submission.actual_down_speed   = row['downloadThroughput']
      submission.actual_upload_speed = row['uploadThroughput']
      submission.set_census_code(row['client_latitude'], row['client_longitude'])
      submission.save
    end
  end

  def self.import
    client = bigquery_init
    zip_codes = "'#{Submission::ZIP_CODES.join("','")}'"

    upload_test_data = client.sql(upload_query(zip_codes))
    download_test_data = client.sql(download_query(zip_codes))

    create_submissions(upload_test_data, 'upload')
    create_submissions(download_test_data, 'download')
  end

  def self.time_constraints
    start_time = Submission.from_mlab.last.created_at.strftime("%Y-%m-%d %H:%M:%S")
    end_time = Date.today.strftime("%Y-%m-%d %H:%M:%S")
    "web100_log_entry.log_time >= PARSE_UTC_USEC('#{start_time}') / POW(10, 6) AND
    web100_log_entry.log_time < PARSE_UTC_USEC('#{end_time}') / POW(10, 6) AND" if Submission.from_mlab.count > 0
  end

  def self.upload_query(zip_codes)
    "SELECT
      test_id,
      STRFTIME_UTC_USEC(INTEGER(web100_log_entry.log_time) * 1000000, '%Y-%m-%d %T') AS UTC_date_time,
      PARSE_IP(connection_spec.client_ip) AS client_ip_numeric,
      connection_spec.client_hostname AS client_hostname,
      connection_spec.client_application AS client_app,
      connection_spec.client_geolocation.city AS city,
      connection_spec.client_geolocation.latitude AS client_latitude,
      connection_spec.client_geolocation.longitude AS client_longitude,
      connection_spec.client_geolocation.postal_code AS postal_code,
      connection_spec.client_geolocation.area_code AS area_code,
      8 * web100_log_entry.snap.HCThruOctetsReceived/web100_log_entry.snap.Duration AS uploadThroughput,
      NULL AS downloadThroughput,
      web100_log_entry.snap.Duration AS duration,
      web100_log_entry.snap.HCThruOctetsReceived AS HCThruOctetsRecv
    FROM [plx.google:m_lab.ndt.all]
    WHERE
      #{time_constraints.to_s}
      connection_spec.client_geolocation.longitude > -85.948441 AND
      connection_spec.client_geolocation.longitude < -85.4051 AND
      connection_spec.client_geolocation.latitude > 37.9971 AND
      connection_spec.client_geolocation.latitude < 38.38051 AND
      connection_spec.client_geolocation.postal_code IN (#{zip_codes}) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.Duration) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.HCThruOctetsReceived) AND
      web100_log_entry.snap.HCThruOctetsReceived >= 8192 AND
      web100_log_entry.snap.Duration >= 9000000 AND
      web100_log_entry.snap.Duration < 3600000000 AND
      blacklist_flags == 0;"
  end

  def self.download_query(zip_codes)
    "SELECT
      test_id,
      STRFTIME_UTC_USEC((INTEGER(web100_log_entry.log_time) * 1000000), '%Y-%m-%d %T') AS UTC_date_time,
      PARSE_IP(connection_spec.client_ip) AS client_ip_numeric,
      connection_spec.client_hostname AS client_hostname,
      connection_spec.client_application AS client_app,
      connection_spec.client_geolocation.city AS city,
      connection_spec.client_geolocation.latitude AS client_latitude,
      connection_spec.client_geolocation.longitude AS client_longitude,
      connection_spec.client_geolocation.postal_code AS postal_code,
      connection_spec.client_geolocation.area_code AS area_code,
      8 * web100_log_entry.snap.HCThruOctetsAcked/ (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) AS downloadThroughput,
      NULL AS uploadThroughput,
      web100_log_entry.snap.HCThruOctetsAcked AS HCThruOctetsAcked,
    FROM [plx.google:m_lab.ndt.all]
    WHERE
      #{time_constraints.to_s}
      connection_spec.client_geolocation.longitude > -85.948441 AND
      connection_spec.client_geolocation.longitude < -85.4051 AND
      connection_spec.client_geolocation.latitude > 37.9971 AND
      connection_spec.client_geolocation.latitude < 38.38051 AND
      connection_spec.client_geolocation.postal_code IN (#{zip_codes}) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.SndLimTimeRwin) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.SndLimTimeCwnd) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.SndLimTimeSnd) AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.HCThruOctetsAcked) AND
      IS_EXPLICITLY_DEFINED(connection_spec.data_direction) AND
      connection_spec.data_direction = 1 AND
      web100_log_entry.snap.HCThruOctetsAcked >= 8192 AND
      (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) >= 9000000 AND
      (web100_log_entry.snap.SndLimTimeRwin + web100_log_entry.snap.SndLimTimeCwnd + web100_log_entry.snap.SndLimTimeSnd) < 3600000000 AND
      IS_EXPLICITLY_DEFINED(web100_log_entry.snap.CongSignals) AND
      web100_log_entry.snap.CongSignals > 0 AND
      blacklist_flags == 0;"
  end

end
