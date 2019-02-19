Hydra::Works.default_system_virus_scanner = Hyc::VirusScanner

Clamby.configure({
                     :check => false,
                     :daemonize => (ENV['clamd'] || false),
                     :config_file => nil,
                     :error_clamscan_missing => true,
                     :error_clamscan_client_error => false,
                     :error_file_missing => true,
                     :error_file_virus => false,
                     :fdpass => true,
                     :stream => false,
                     :output_level => 'high', # one of 'off', 'low', 'medium', 'high'
                     :executable_path_clamscan => 'clamscan',
                     :executable_path_clamdscan => 'clamdscan',
                     :executable_path_freshclam => 'freshclam',
                 })
