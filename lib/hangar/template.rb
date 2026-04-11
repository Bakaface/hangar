module Hangar
  module Template
    def self.init(name)
      dest = File.join(Dir.pwd, Config.config_filename)
      if File.exist?(dest)
        $stderr.puts "#{Config.config_filename} already exists in this directory"
        exit 1
      end

      source = find_template(name)
      if source.nil?
        $stderr.puts "Unknown template: #{name}"
        $stderr.puts "Available templates: #{available_names.join(', ')}"
        exit 1
      end

      FileUtils.cp(source, dest)
      puts "Created #{Config.config_filename} from '#{name}' template"
    end

    def self.list
      available_names.each { |name| puts name }
    end

    def self.create(name)
      if name.nil? || name.empty?
        $stderr.puts "Usage: hangar template new <name>"
        exit 1
      end

      Config.ensure_data_dir
      FileUtils.mkdir_p(Config.user_templates_dir)

      path = File.join(Config.user_templates_dir, "#{name}.sh")
      if File.exist?(path)
        $stderr.puts "Template '#{name}' already exists"
        exit 1
      end

      File.write(path, default_template_content)
      editor = ENV.fetch("EDITOR", "vim")
      exec(editor, path)
    end

    def self.edit(name)
      if name.nil? || name.empty?
        $stderr.puts "Usage: hangar template edit <name>"
        exit 1
      end

      # Prefer user template, fall back to copying builtin for editing
      user_path = File.join(Config.user_templates_dir, "#{name}.sh")
      if File.exist?(user_path)
        editor = ENV.fetch("EDITOR", "vim")
        exec(editor, user_path)
      end

      builtin_path = File.join(Config.builtin_templates_dir, "#{name}.sh")
      if File.exist?(builtin_path)
        Config.ensure_data_dir
        FileUtils.mkdir_p(Config.user_templates_dir)
        FileUtils.cp(builtin_path, user_path)
        editor = ENV.fetch("EDITOR", "vim")
        exec(editor, user_path)
      end

      $stderr.puts "Unknown template: #{name}"
      exit 1
    end

    def self.find_template(name)
      # User templates override builtins
      user_path = File.join(Config.user_templates_dir, "#{name}.sh")
      return user_path if File.exist?(user_path)

      builtin_path = File.join(Config.builtin_templates_dir, "#{name}.sh")
      return builtin_path if File.exist?(builtin_path)

      nil
    end

    def self.available_names
      builtins = Dir.glob(File.join(Config.builtin_templates_dir, "*.sh")).map { |f| File.basename(f, ".sh") }
      user = if Dir.exist?(Config.user_templates_dir)
        Dir.glob(File.join(Config.user_templates_dir, "*.sh")).map { |f| File.basename(f, ".sh") }
      else
        []
      end
      (builtins + user).uniq.sort
    end

    def self.default_template_content
      <<~BASH
        # shortcut "xx"

        init_basic
      BASH
    end
  end
end
