module Hangar
  module Project
    def self.add(path, aliaz = nil)
      path = File.expand_path(path)
      config = File.join(path, Config.config_filename)

      unless File.exist?(config)
        $stderr.puts "No #{Config.config_filename} found in #{path}"
        exit 1
      end

      Config.ensure_data_dir
      if load_registry.include?(path)
        puts "Already registered: #{path}"
        return
      end

      entry = aliaz && !aliaz.empty? ? "#{path}\t#{aliaz}" : path
      File.open(Config.registry_file, "a") { |f| f.puts(entry) }
      puts aliaz ? "Registered: #{path} as '#{aliaz}'" : "Registered: #{path}"
    end

    def self.remove(query)
      match = resolve(query)
      return unless match

      raw = raw_registry.reject { |path, _| path == match }
      write_raw_registry(raw)
      puts "Removed: #{match}"
    end

    def self.rename(query, new_alias)
      match = resolve(query)
      return unless match

      if new_alias.include?("\t")
        $stderr.puts "hangar: alias may not contain tabs"
        exit 1
      end

      old_name = session_name(match)
      new_alias = new_alias.strip
      raw = raw_registry.map do |path, aliaz|
        path == match ? [path, (new_alias unless new_alias.empty?)] : [path, aliaz]
      end
      write_raw_registry(raw)

      new_name = session_name(match)
      if old_name != new_name && Session.session_exists?(old_name)
        system("tmux", "rename-session", "-t", old_name, new_name)
      end

      Bindings.generate(bind: true) if Session.inside_tmux?

      puts new_alias.empty? ? "Renamed: #{match} (alias cleared, now '#{new_name}')" : "Renamed: #{match} as '#{new_alias}'"
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
      match = find_project_dir(query)
      return unless match

      editor = ENV.fetch("EDITOR", "vim")
      config = File.join(match, Config.config_filename)
      system(editor, config)

      # Refresh tmux keybindings in case shortcuts were changed
      Bindings.generate(bind: true) if Session.inside_tmux?
    end

    def self.raw_registry
      return [] unless File.exist?(Config.registry_file)
      File.readlines(Config.registry_file).map(&:strip).reject(&:empty?).map do |line|
        path, aliaz = line.split("\t", 2)
        [path, (aliaz if aliaz && !aliaz.empty?)]
      end
    end

    def self.load_registry
      raw_registry.map(&:first)
    end

    def self.load_aliases
      raw_registry.each_with_object({}) do |(path, aliaz), h|
        h[path] = aliaz if aliaz
      end
    end

    def self.write_raw_registry(entries)
      Config.ensure_data_dir
      lines = entries.map { |path, aliaz| aliaz ? "#{path}\t#{aliaz}" : path }
      File.write(Config.registry_file, lines.join("\n") + "\n")
    end

    def self.session_name(path)
      name = load_aliases[path] || File.basename(path)
      name.tr(".:", "_")
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
