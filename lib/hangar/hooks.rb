module Hangar
  module Hooks
    NAMES = %w[before-init after-init after-kill after-up].freeze

    def self.run(name, env = {})
      path = File.join(Config.config_dir, "#{name}.sh")
      return unless File.exist?(path)

      string_env = env.transform_keys(&:to_s).transform_values(&:to_s)
      pid = Process.spawn(string_env, "bash", path)
      _, status = Process.wait2(pid)
      return if status.success?

      $stderr.puts "hangar: hook '#{name}' failed (exit #{status.exitstatus})"
      exit(status.exitstatus || 1)
    end
  end
end
