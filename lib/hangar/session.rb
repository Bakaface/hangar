require "tmpdir"
require "shellwords"

module Hangar
  module Session
    def self.open(query)
      project_dir = Project.find_project_dir(query)
      return if project_dir.nil?

      name = Project.session_name(project_dir)

      # Auto-register if not already registered
      unless Project.load_registry.include?(project_dir)
        Project.add(project_dir)
      end

      # Refresh tmux keybindings so new/changed shortcuts activate immediately
      Bindings.generate(bind: true) if inside_tmux?

      # If session already running, attach to it
      if session_exists?(name)
        attach(name)
        return
      end

      # Generate and run wrapper script
      script = generate_wrapper(name, project_dir)
      system("bash", script, inside_tmux? ? "" : "a")

      # When inside tmux, follow the newly created session
      exec("tmux", "switch-client", "-t", name) if inside_tmux?
    end

    def self.kill(query)
      name = if query
        query
      else
        sessions = running_session_names
        return puts("No running sessions") if sessions.empty?

        result = IO.popen("fzf", "r+") do |fzf|
          fzf.write(sessions.join("\n"))
          fzf.close_write
          fzf.read.strip
        end
        return if result.empty?
        result
      end

      system("tmux", "kill-session", "-t", name)
      puts "Killed session: #{name}"
    end

    def self.list
      sessions = running_sessions
      if sessions.empty?
        puts "No running sessions"
      else
        sessions.each { |s| puts s }
      end
    end

    def self.switch
      names = running_session_names
      if names.empty?
        $stderr.puts "No running sessions"
        exit 1
      end

      marks = Marks.load_marks
      lines = names.map do |name|
        mark = marks.find { |_k, v| v == name }&.first
        mark ? format("%-4s %s", mark, name) : format("     %s", name)
      end

      result = IO.popen("fzf --header='Switch Session'", "r+") do |fzf|
        fzf.write(lines.join("\n"))
        fzf.close_write
        fzf.read.strip
      end
      return if result.empty?

      session = result.sub(/^\S*\s*/, "")
      exec("tmux", "switch-client", "-t", session)
    end

    def self.running_session_names
      output = `tmux list-sessions -F '\#{session_name}' 2>/dev/null`.strip
      return [] if output.empty?
      output.split("\n")
    end

    def self.running_sessions
      output = `tmux list-sessions 2>/dev/null`.strip
      return [] if output.empty?
      output.split("\n")
    end

    def self.session_exists?(name)
      system("tmux", "has-session", "-t", name, err: File::NULL)
    end

    def self.inside_tmux?
      ENV.key?("TMUX")
    end

    def self.attach(name)
      if inside_tmux?
        exec("tmux", "switch-client", "-t", name)
      else
        exec("tmux", "attach-session", "-t", name)
      end
    end

    def self.generate_wrapper(name, project_dir)
      config_file = File.join(project_dir, Config.config_filename)
      lib_sh = Config.lib_sh

      script = <<~BASH
        #!/usr/bin/env bash
        session=#{Shellwords.escape(name)}
        path=#{Shellwords.escape(project_dir)}
        repo=#{Shellwords.escape(project_dir)}

        source #{Shellwords.escape(lib_sh)}
        cd #{Shellwords.escape(project_dir)}
        source #{Shellwords.escape(config_file)}

        attach $1
      BASH

      tmpfile = File.join(Dir.tmpdir, "hangar-#{name}-#{$$}.sh")
      File.write(tmpfile, script)
      tmpfile
    end
  end
end
