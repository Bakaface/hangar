module Hangar
  module Config
    def self.data_dir
      dir = ENV.fetch("XDG_DATA_HOME", File.expand_path("~/.local/share"))
      File.join(dir, "hangar")
    end

    def self.registry_file
      File.join(data_dir, "projects")
    end

    def self.marks_file
      File.join(data_dir, "marks")
    end

    def self.user_templates_dir
      File.join(data_dir, "templates")
    end

    def self.share_dir
      File.expand_path("../../share/hangar", __dir__)
    end

    def self.lib_sh
      File.join(share_dir, "lib.sh")
    end

    def self.builtin_templates_dir
      File.join(share_dir, "templates")
    end

    def self.ensure_data_dir
      FileUtils.mkdir_p(data_dir)
    end

    def self.config_filename
      ".hangar.sh"
    end
  end
end
