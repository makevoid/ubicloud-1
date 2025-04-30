# frozen_string_literal: true

module MetricsTargetMethods
  MAX_SCRAPE_FETCH_COUNT = 4
  FILENAME_FORMAT = "%Y-%m-%dT%H-%M-%S-%N"

  def metrics_config
    {
      # Array of endpoints to collect metrics from
      endpoints: [],

      # Maximum number of entries in the pending buffer
      max_pending_buffer_size: 120,

      # Interval for collecting metrics in seconds or as a time span string
      interval: "15s",

      # Additional label names and values to be added to the collected metrics
      additional_labels: {foo: "bar"},

      # Directory to store the collected metrics
      metrics_dir: "/home/ubi/metrics"
    }
  end

  def export_metrics(session:, tsdb_client:)
    Clog.emit("Exporting metrics from target.")
    scrape_results = scrape_endpoints(session)
    Clog.emit("Scrape results") { {num_scrape_results: scrape_results.count} }

    if scrape_results.empty?
      return
    end

    scrape_results.each do |scrape|
      tsdb_client.import_prometheus(scrape, metrics_config[:additional_labels])
    end

    mark_pending_scrapes_as_done(session, scrape_results[-1].time)
  end

  def scrape_endpoints(session)
    scrape_files = session[:ssh_session].exec!("ls #{metrics_dir}/pending | sort | head -n #{MAX_SCRAPE_FETCH_COUNT}").split("\n")
    Clog.emit("Listed pending files") { {num_scrape_files: scrape_files.count} }

    scrape_files.filter_map do |file|
      Clog.emit("Processing file") { {file: file} }
      time_str = file.split(".").first
      time = Time.strptime(time_str, FILENAME_FORMAT)
      status = {}

      scrape_content = session[:ssh_session].exec!("cat #{metrics_dir}/pending/#{file}", status: status)
      Clog.emit("Got file read exit code") { {exit_code: status[:exit_code]} }

      VictoriaMetrics::Client::Scrape.new(time: time, samples: scrape_content) unless status[:exit_code] != 0
    end
  end

  def mark_pending_scrapes_as_done(session, time)
    marker = time.strftime(FILENAME_FORMAT)
    session[:ssh_session].exec!("ls #{metrics_dir}/pending | sort | awk '$0 <= \"#{marker}\"' | xargs -I{} mv #{metrics_dir}/pending/{} #{metrics_dir}/done/")
  end

  def metrics_dir
    metrics_config[:metrics_dir].shellescape
  end
end
