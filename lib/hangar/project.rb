module Hangar
  module Project
    def self.add(path)
      path = File.expand_path(path)
      config = File.join(path, Config.config_filename)

      unless File.exist?(config)
        $stderr.puts "No #{Config.config_filename} found in #{path}"
        exit 1
      end

      Config.ensure_data_dir
      entries = load_registry
      if entries.include?(path)
        puts "Already registered: #{path}"
        return
      end

      File.open(Config.registry_file, "a") { |f| f.puts(path) }
      puts "Registered: #{path}"
    end

    def self.remove(query)
      entries = load_registry
      match = resolve(query, entries)
      return unless match

      entries.delete(match)
      write_registry(entries)
      puts "Removed: #{match}"
    end

    def self.list
      entries = load_registry
      running = Session.running_session_names

      entries.each do |path|
        name = session_name(path)
        status = running.include?(name) ? " (running)" : ""
        puts "#{name}#{status}  #{path}"
      end
    end

    def self.edit(query)
      entries = load_registry
      match = resolve(query, entries)
      return unless match

      editor = ENV.fetch("EDITOR", "vim")
      config = File.join(match, Config.config_filename)
      exec(editor, config)
    end

    def self.load_registry
      return [] unless File.exist?(Config.registry_file)
      File.readlines(Config.registry_file).map(&:strip).reject(&:empty?)
    end

    def self.write_registry(entries)
      Config.ensure_data_dir
      File.write(Config.registry_file, entries.join("\n") + "\n")
    end

    def self.session_name(path)
      File.basename(path)
    end

    def self.resolve(query, entries = load_registry)
      return nil if entries.empty?

      if query.nil?
        select_with_fzf(entries)
      else
        exact = entries.find { |e| session_name(e) == query }
        return exact if exact

        matches = entries.select { |e| session_name(e).include?(query) || e.include?(query) }
        case matches.size
        when 0
          $stderr.puts "No project matching '#{query}'"
          nil
        when 1
          matches.first
        else
          select_with_fzf(matches)
        end
      end
    end

    def self.select_with_fzf(entries)
      return nil if entries.empty?

      items = entries.map { |e| "#{session_name(e)}\t#{e}" }.join("\n")
      result = IO.popen("fzf --with-nth=1 --delimiter='\t'", "r+") do |fzf|
        fzf.write(items)
        fzf.close_write
        fzf.read.strip
      end

      return nil if result.empty?
      result.split("\t").last
    end

    def self.find_project_dir(query)
      entries = load_registry
      if query
        resolve(query, entries)
      else
        cwd = Dir.pwd
        if entries.include?(cwd)
          cwd
        elsif File.exist?(File.join(cwd, Config.config_filename))
          cwd
        else
          select_with_fzf(entries)
        end
      end
    end
  end
end
